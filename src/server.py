#!/usr/bin/env python3
"""FreeChatGPT v3.0 ULTIMATE - Complete AI System"""
from flask import Flask, render_template, request, jsonify, Response, stream_with_context
import requests, json, os, logging, sqlite3, uuid, time, base64, hashlib
from datetime import datetime
from werkzeug.utils import secure_filename

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config.update(SECRET_KEY=os.urandom(24), MAX_CONTENT_LENGTH=100*1024*1024,
    UPLOAD_FOLDER='src/static/uploads', AUDIO_FOLDER='src/static/audio', DATABASE='data/freechatgpt.db')

for f in [app.config['UPLOAD_FOLDER'], app.config['AUDIO_FOLDER'], 'data']:
    os.makedirs(f, exist_ok=True)

OLLAMA_API = "http://localhost:11434"
ALLOWED = {'txt','pdf','png','jpg','jpeg','gif','doc','docx','csv','json','mp3','wav','ogg','webm'}

MODELS = {
    "llama3.2:3b": {"name":"Llama 3.2","emoji":"⚡","desc":"Fast & accurate","vram":"3GB"},
    "mistral:7b": {"name":"Mistral 7B","emoji":"✨","desc":"Creative","vram":"5GB"},
    "qwen2.5:3b": {"name":"Qwen 2.5","emoji":"🚀","desc":"Ultra-fast","vram":"3GB"}
}

def init_db():
    conn = sqlite3.connect(app.config['DATABASE'])
    c = conn.cursor()
    c.execute('CREATE TABLE IF NOT EXISTS conversations (id TEXT PRIMARY KEY, title TEXT, language TEXT, created_at INTEGER, updated_at INTEGER)')
    c.execute('CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id TEXT, role TEXT, content TEXT, model_used TEXT, response_time_ms INTEGER, created_at INTEGER, FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE)')
    c.execute('CREATE TABLE IF NOT EXISTS voice_messages (id TEXT PRIMARY KEY, conversation_id TEXT, audio_path TEXT, transcription TEXT, language TEXT, duration REAL, created_at INTEGER)')
    c.execute('CREATE TABLE IF NOT EXISTS files (id TEXT PRIMARY KEY, conversation_id TEXT, filename TEXT, filepath TEXT, file_size INTEGER, file_type TEXT, content_extracted TEXT, uploaded_at INTEGER)')
    c.execute('CREATE TABLE IF NOT EXISTS feedback (id INTEGER PRIMARY KEY AUTOINCREMENT, message_id INTEGER, rating INTEGER, created_at INTEGER)')
    c.execute('CREATE TABLE IF NOT EXISTS training_log (id INTEGER PRIMARY KEY AUTOINCREMENT, user_input TEXT, ai_response TEXT, model TEXT, context TEXT, quality REAL, language TEXT, created_at INTEGER)')
    conn.commit()
    conn.close()
    logger.info("✅ Database initialized")

init_db()

def get_db():
    c = sqlite3.connect(app.config['DATABASE'])
    c.row_factory = sqlite3.Row
    return c

def log_training(user, ai, model, ctx="", qual=1.0, lang="en"):
    try:
        c = get_db()
        cur = c.cursor()
        cur.execute('INSERT INTO training_log (user_input,ai_response,model,context,quality,language,created_at) VALUES (?,?,?,?,?,?,?)',
                   (user,ai,model,ctx,qual,lang,int(time.time()*1000)))
        c.commit()
        c.close()
    except Exception as e:
        logger.error(f"Log error: {e}")

def check_ollama():
    try: return requests.get(f"{OLLAMA_API}/api/tags", timeout=5).status_code == 200
    except: return False

def get_models():
    try:
        r = requests.get(f"{OLLAMA_API}/api/tags")
        return [m['name'] for m in r.json().get('models',[])] if r.status_code==200 else []
    except: return []

@app.route('/')
def index(): return render_template('index.html')

@app.route('/api/status')
def status():
    on = check_ollama()
    return jsonify({'ollama_running':on, 'available_models':get_models() if on else [],
                   'recommended_models':MODELS, 'features':{'voice':True,'rag':True,'logging':True,'multilang':True}})

@app.route('/api/chat', methods=['POST'])
def chat():
    d = request.json
    msg, model, cid, lang = d.get('message',''), d.get('model','llama3.2:3b'), d.get('conversation_id'), d.get('language','en')
    if not msg: return jsonify({'error':'No message'}), 400
    
    start = time.time()
    c = get_db()
    cur = c.cursor()
    hist = []
    
    if cid:
        cur.execute('SELECT role,content FROM messages WHERE conversation_id=? ORDER BY created_at DESC LIMIT 20',(cid,))
        hist = [{'role':r['role'],'content':r['content']} for r in reversed(cur.fetchall())]
        cur.execute('INSERT INTO messages (conversation_id,role,content,model_used,created_at) VALUES (?,?,?,?,?)',
                   (cid,'user',msg,model,int(time.time()*1000)))
        c.commit()
    
    # RAG context
    ctx = ""
    if cid:
        cur.execute('SELECT content_extracted FROM files WHERE conversation_id=? AND content_extracted IS NOT NULL LIMIT 3',(cid,))
        docs = cur.fetchall()
        if docs: ctx = "\n\nKnowledge:\n" + "\n".join([d['content_extracted'][:800] for d in docs])
    c.close()
    
    sys = f"You are FreeChatGPT. Language: {lang}. Be helpful and concise.{ctx}"
    msgs = [{'role':'system','content':sys}] + hist + [{'role':'user','content':msg}]
    
    def generate():
        full = ''
        try:
            r = requests.post(f"{OLLAMA_API}/api/chat", json={'model':model,'messages':msgs,'stream':True,
                'options':{'temperature':0.7,'num_ctx':8192}}, stream=True, timeout=300)
            for line in r.iter_lines():
                if line:
                    chunk = json.loads(line)
                    if 'message' in chunk:
                        content = chunk['message'].get('content','')
                        if content:
                            nonlocal full
                            full += content
                            yield f"data: {json.dumps({'content':content})}\n\n"
                    if chunk.get('done'):
                        rtime = int((time.time()-start)*1000)
                        if cid and full:
                            c = get_db()
                            cur = c.cursor()
                            cur.execute('INSERT INTO messages (conversation_id,role,content,model_used,response_time_ms,created_at) VALUES (?,?,?,?,?,?)',
                                       (cid,'assistant',full,model,rtime,int(time.time()*1000)))
                            cur.execute('UPDATE conversations SET updated_at=? WHERE id=?', (int(time.time()*1000),cid))
                            c.commit()
                            c.close()
                            log_training(msg, full, model, ctx, 1.0, lang)
                        yield f"data: {json.dumps({'done':True,'time':rtime})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error':str(e)})}\n\n"
    
    return Response(stream_with_context(generate()), mimetype='text/event-stream')

@app.route('/api/transcribe', methods=['POST'])
def transcribe():
    if 'audio' not in request.files: return jsonify({'error':'No audio'}), 400
    audio = request.files['audio']
    cid = request.form.get('conversation_id','')
    
    aid = str(uuid.uuid4())
    fname = f"{aid}.webm"
    path = os.path.join(app.config['AUDIO_FOLDER'], fname)
    audio.save(path)
    
    # Placeholder - add Whisper integration
    trans = "[Voice: Install Whisper for transcription]"
    lang = "en"
    
    c = get_db()
    cur = c.cursor()
    cur.execute('INSERT INTO voice_messages (id,conversation_id,audio_path,transcription,language,duration,created_at) VALUES (?,?,?,?,?,?,?)',
               (aid,cid,fname,trans,lang,0,int(time.time()*1000)))
    c.commit()
    c.close()
    
    return jsonify({'success':True,'transcription':trans,'language':lang})

@app.route('/api/upload', methods=['POST'])
def upload():
    if 'file' not in request.files: return jsonify({'error':'No file'}), 400
    file = request.files['file']
    cid = request.form.get('conversation_id','')
    if not file.filename: return jsonify({'error':'No filename'}), 400
    
    if file and '.' in file.filename:
        ext = file.filename.rsplit('.',1)[1].lower()
        if ext in ALLOWED:
            fname = secure_filename(file.filename)
            unique = f"{uuid.uuid4()}_{fname}"
            path = os.path.join(app.config['UPLOAD_FOLDER'], unique)
            file.save(path)
            
            content = ""
            if ext == 'txt':
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        content = f.read()[:20000]
                except: pass
            
            fid = str(uuid.uuid4())
            c = get_db()
            cur = c.cursor()
            cur.execute('INSERT INTO files (id,conversation_id,filename,filepath,file_size,file_type,content_extracted,uploaded_at) VALUES (?,?,?,?,?,?,?,?)',
                       (fid,cid,fname,unique,os.path.getsize(path),ext,content,int(time.time()*1000)))
            c.commit()
            c.close()
            
            return jsonify({'success':True,'file_id':fid,'filename':fname,'has_content':bool(content)})
    return jsonify({'error':'Invalid file'}), 400

@app.route('/api/conversations', methods=['GET'])
def get_convs():
    c = get_db()
    cur = c.cursor()
    cur.execute('SELECT c.id,c.title,c.language,c.created_at,c.updated_at,COUNT(m.id) as cnt FROM conversations c LEFT JOIN messages m ON c.id=m.conversation_id GROUP BY c.id ORDER BY c.updated_at DESC LIMIT 100')
    convs = [dict(r) for r in cur.fetchall()]
    c.close()
    return jsonify({'conversations':convs})

@app.route('/api/conversations/<cid>', methods=['GET','POST','DELETE'])
def manage_conv(cid):
    c = get_db()
    cur = c.cursor()
    if request.method == 'GET':
        cur.execute('SELECT * FROM conversations WHERE id=?',(cid,))
        conv = cur.fetchone()
        if not conv: return jsonify({'error':'Not found'}), 404
        cur.execute('SELECT role,content,model_used,created_at FROM messages WHERE conversation_id=? ORDER BY created_at',(cid,))
        msgs = [dict(r) for r in cur.fetchall()]
        c.close()
        return jsonify({**dict(conv),'messages':msgs})
    elif request.method == 'POST':
        d = request.json
        title, lang = d.get('title','New Chat'), d.get('language','en')
        ts = int(time.time()*1000)
        cur.execute('SELECT id FROM conversations WHERE id=?',(cid,))
        if cur.fetchone():
            cur.execute('UPDATE conversations SET title=?,language=?,updated_at=? WHERE id=?',(title,lang,ts,cid))
        else:
            cur.execute('INSERT INTO conversations VALUES (?,?,?,?,?)',(cid,title,lang,ts,ts))
        c.commit()
        c.close()
        return jsonify({'success':True})
    elif request.method == 'DELETE':
        cur.execute('DELETE FROM conversations WHERE id=?',(cid,))
        c.commit()
        c.close()
        return jsonify({'success':True})

@app.route('/api/feedback', methods=['POST'])
def feedback():
    d = request.json
    c = get_db()
    cur = c.cursor()
    cur.execute('INSERT INTO feedback (message_id,rating,created_at) VALUES (?,?,?)',
               (d.get('message_id'),d.get('rating'),int(time.time()*1000)))
    c.commit()
    c.close()
    return jsonify({'success':True})

@app.route('/api/export-training')
def export_training():
    c = get_db()
    cur = c.cursor()
    cur.execute('SELECT user_input,ai_response,model,language,quality,created_at FROM training_log ORDER BY created_at DESC LIMIT 10000')
    data = []
    for r in cur.fetchall():
        data.append({
            'messages':[{'role':'user','content':r['user_input']},{'role':'assistant','content':r['ai_response']}],
            'metadata':{'model':r['model'],'lang':r['language'],'quality':r['quality'],'ts':r['created_at']}
        })
    c.close()
    jsonl = '\n'.join([json.dumps(i) for i in data])
    return Response(jsonl, mimetype='application/jsonl', headers={'Content-Disposition':'attachment; filename=training.jsonl'})

@app.route('/api/stats')
def stats():
    c = get_db()
    cur = c.cursor()
    cur.execute('SELECT COUNT(*) as n FROM training_log')
    total = cur.fetchone()['n']
    cur.execute('SELECT COUNT(*) as n FROM voice_messages')
    voice = cur.fetchone()['n']
    cur.execute('SELECT COUNT(*) as n FROM files WHERE content_extracted IS NOT NULL')
    docs = cur.fetchone()['n']
    c.close()
    return jsonify({'total_interactions':total,'voice_messages':voice,'documents':docs})

@app.route('/health')
def health():
    return jsonify({'status':'healthy','version':'3.0','ollama':check_ollama(),'db':os.path.exists(app.config['DATABASE'])})

if __name__ == '__main__':
    print("""
╔══════════════════════════════════════════════════════════════╗
║           🚀 FreeChatGPT v3.0 ULTIMATE 🚀                    ║
║                                                              ║
║  ✨ Voice Input • 📊 Logging • 🧠 RAG • 🌍 Multi-Language  ║
║                                                              ║
║  By: 833K-cpu | http://localhost:5000                      ║
╚══════════════════════════════════════════════════════════════╝
""")
    if check_ollama():
        m = get_models()
        print(f"✅ Ollama: {len(m)} models | Database: {app.config['DATABASE']}\n")
    else:
        print("❌ Start Ollama: ollama serve\n")
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
