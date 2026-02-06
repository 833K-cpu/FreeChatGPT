#!/bin/bash
# Complete UI Builder for FreeChatGPT v3.0

# HTML Template
cat > src/templates/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>FreeChatGPT</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/styles.css') }}">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
</head>
<body class="dark-theme">
    <div class="sidebar" id="sidebar">
        <div class="sidebar-header">
            <button class="new-chat" onclick="newChat()"><i class="fas fa-plus"></i> New chat</button>
        </div>
        <div class="sidebar-list" id="convList"></div>
        <div class="sidebar-footer">
            <div class="user"><div class="avatar"><i class="fas fa-user"></i></div><div class="info"><div class="name">833K-cpu</div><div class="status"><span class="dot" id="dot"></span><span id="status">...</span></div></div></div>
        </div>
    </div>
    <div class="main">
        <div class="topbar">
            <button class="toggle" onclick="toggleSidebar()"><i class="fas fa-bars"></i></button>
            <select id="model" onchange="changeModel()"><option value="llama3.2:3b">ChatGPT 3.5</option></select>
        </div>
        <div class="chat" id="chat">
            <div class="welcome" id="welcome"><h1>FreeChatGPT</h1><p>How can I help you today?</p></div>
            <div class="messages" id="msgs"></div>
        </div>
        <div class="input-area">
            <div class="input-box">
                <button class="attach" onclick="document.getElementById('file').click()"><i class="fas fa-paperclip"></i></button>
                <input type="file" id="file" style="display:none" onchange="handleFile(event)" multiple>
                <div id="files"></div>
                <textarea id="input" placeholder="Message FreeChatGPT..." rows="1" onkeydown="handleKey(event)"></textarea>
                <button class="voice" id="voice" onmousedown="startVoice()" onmouseup="stopVoice()"><i class="fas fa-microphone"></i></button>
                <button class="send" id="send" onclick="send()" disabled><i class="fas fa-arrow-up"></i></button>
            </div>
            <div class="footer">FreeChatGPT can make mistakes. Check important info.</div>
        </div>
    </div>
    <script src="{{ url_for('static', filename='js/app.js') }}"></script>
</body>
</html>
HTML

# CSS
cat > src/static/css/styles.css << 'CSS'
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;display:flex;height:100vh;overflow:hidden;background:#212121;color:#ececec}
.dark-theme{--bg:#212121;--bg2:#2f2f2f;--sidebar:#171717;--text:#ececec;--text2:#b4b4b4;--border:#4d4d4f;--accent:#19c37d;--accent-hover:#0fa968}
.sidebar{width:260px;background:var(--sidebar);display:flex;flex-direction:column;border-right:1px solid var(--border)}
.sidebar-header{padding:12px}
.new-chat{width:100%;padding:10px;background:transparent;border:1px solid var(--border);border-radius:8px;color:var(--text);cursor:pointer;font-size:14px;transition:.15s}
.new-chat:hover{background:var(--bg2)}
.sidebar-list{flex:1;overflow-y:auto;padding:8px}
.conv-item{padding:10px 12px;border-radius:8px;cursor:pointer;margin-bottom:2px;color:var(--text2);font-size:14px;transition:.15s}
.conv-item:hover,.conv-item.active{background:var(--bg2);color:var(--text)}
.sidebar-footer{padding:12px;border-top:1px solid var(--border)}
.user{display:flex;align-items:center;gap:10px}
.avatar{width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,var(--accent),#0d8c6d);display:flex;align-items:center;justify-content:center;font-size:14px;color:#fff}
.info{flex:1}
.name{font-size:14px;font-weight:500}
.status{display:flex;align-items:center;gap:6px;font-size:12px;color:var(--text2)}
.dot{width:8px;height:8px;border-radius:50%;background:gray}
.dot.on{background:var(--accent);box-shadow:0 0 6px var(--accent)}
.main{flex:1;display:flex;flex-direction:column}
.topbar{padding:12px 16px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:15px}
.toggle{width:36px;height:36px;border-radius:6px;background:transparent;border:none;color:var(--text);cursor:pointer;font-size:18px;display:none}
.toggle:hover{background:var(--bg2)}
#model{padding:8px 12px;background:var(--bg2);border:1px solid var(--border);border-radius:8px;color:var(--text);font-size:13px;cursor:pointer}
.chat{flex:1;overflow-y:auto;padding:24px 0}
.welcome{display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;text-align:center}
.welcome h1{font-size:40px;margin-bottom:8px}
.welcome p{color:var(--text2);font-size:18px}
.messages{max-width:800px;margin:0 auto;width:100%;padding:0 24px}
.message{padding:20px 0;margin-bottom:16px;line-height:1.7}
.message.user{background:var(--bg2);border-radius:16px;padding:20px}
.msg-header{display:flex;align-items:center;gap:12px;margin-bottom:12px;font-weight:600;font-size:14px}
.msg-icon{width:30px;height:30px;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:16px}
.message.user .msg-icon{background:linear-gradient(135deg,var(--accent),#0d8c6d);color:#fff}
.message.assistant .msg-icon{background:linear-gradient(135deg,#8b5cf6,#6366f1);color:#fff}
.msg-content{color:var(--text);white-space:pre-wrap;word-wrap:break-word;font-size:15px}
.msg-content code{background:#000;padding:2px 6px;border-radius:4px;font-family:monospace;font-size:13px;color:var(--accent)}
.msg-content pre{background:#000;padding:16px;border-radius:8px;overflow-x:auto;margin:12px 0;border:1px solid var(--border)}
.msg-content pre code{background:transparent;padding:0;color:var(--text)}
.typing{display:flex;gap:4px;padding:10px 0}
.typing div{width:8px;height:8px;border-radius:50%;background:var(--text2);animation:typing 1.4s infinite}
.typing div:nth-child(2){animation-delay:.2s}
.typing div:nth-child(3){animation-delay:.4s}
@keyframes typing{0%,60%,100%{opacity:.3;transform:translateY(0)}30%{opacity:1;transform:translateY(-4px)}}
.input-area{padding:16px 24px 24px}
.input-box{max-width:800px;margin:0 auto;display:flex;gap:8px;align-items:flex-end;background:var(--bg2);border:1px solid var(--border);border-radius:24px;padding:12px 16px;position:relative}
.attach,.voice{width:32px;height:32px;border-radius:8px;background:transparent;border:none;color:var(--text2);cursor:pointer;display:flex;align-items:center;justify-content:center;transition:.15s;flex-shrink:0}
.attach:hover,.voice:hover{background:var(--bg);color:var(--text)}
.voice.recording{color:#ef4444;animation:pulse 1s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}
#input{flex:1;background:transparent;border:none;outline:none;color:var(--text);font-size:15px;resize:none;max-height:200px;font-family:inherit;line-height:1.5}
#input::placeholder{color:var(--text2)}
.send{width:32px;height:32px;border-radius:50%;background:var(--accent);border:none;color:#fff;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:.15s;flex-shrink:0}
.send:hover:not(:disabled){background:var(--accent-hover)}
.send:disabled{opacity:.4;cursor:not-allowed}
.footer{text-align:center;margin-top:12px;font-size:12px;color:var(--text2)}
#files{display:flex;gap:8px;flex-wrap:wrap;padding:0 8px}
.file-tag{padding:6px 12px;background:var(--bg);border:1px solid var(--border);border-radius:12px;font-size:12px;display:flex;align-items:center;gap:6px}
.file-tag i{color:var(--accent)}
@media(max-width:768px){.sidebar{position:fixed;left:0;top:0;height:100%;z-index:100;transform:translateX(-100%);transition:.2s}.sidebar.active{transform:translateX(0)}.toggle{display:flex}}
::-webkit-scrollbar{width:8px;height:8px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:var(--border);border-radius:4px}
::-webkit-scrollbar-thumb:hover{background:var(--text2)}
CSS

# JavaScript  
cat > src/static/js/app.js << 'JS'
let convId=null,convs=[],hist=[],model='llama3.2:3b',streaming=false,files=[],mediaRecorder=null,audioChunks=[];

document.addEventListener('DOMContentLoaded',()=>{
    checkStatus();
    loadConvs();
    autoResize();
    setInterval(checkStatus,30000);
});

async function checkStatus(){
    try{
        const r=await fetch('/api/status');
        const d=await r.json();
        document.getElementById('dot').className=d.ollama_running?'dot on':'dot';
        document.getElementById('status').textContent=d.ollama_running?'Online':'Offline';
        if(d.available_models.length){
            const sel=document.getElementById('model');
            sel.innerHTML=d.available_models.map(m=>`<option value="${m}">${d.recommended_models[m]?.name||m}</option>`).join('');
            sel.value=model;
        }
    }catch(e){
        document.getElementById('dot').className='dot';
        document.getElementById('status').textContent='Error';
    }
}

async function loadConvs(){
    try{
        const r=await fetch('/api/conversations');
        const d=await r.json();
        convs=d.conversations||[];
        const list=document.getElementById('convList');
        list.innerHTML=convs.map(c=>`<div class="conv-item ${c.id===convId?'active':''}" onclick="loadConv('${c.id}')">${c.title||'New chat'}</div>`).join('');
        if(convs.length&&!convId)loadConv(convs[0].id);
    }catch(e){console.error(e)}
}

async function loadConv(id){
    try{
        const r=await fetch(`/api/conversations/${id}`);
        const d=await r.json();
        convId=id;
        hist=d.messages||[];
        document.getElementById('welcome').style.display='none';
        const msgs=document.getElementById('msgs');
        msgs.style.display='block';
        msgs.innerHTML='';
        hist.forEach(m=>addMsg(m.role,m.content));
        loadConvs();
    }catch(e){console.error(e)}
}

async function saveConv(){
    if(!convId||!hist.length)return;
    try{
        await fetch(`/api/conversations/${convId}`,{
            method:'POST',
            headers:{'Content-Type':'application/json'},
            body:JSON.stringify({title:hist[0]?.content?.substring(0,30)||'New chat',language:'en'})
        });
    }catch(e){console.error(e)}
}

function newChat(){
    convId=`chat_${Date.now()}`;
    hist=[];
    files=[];
    document.getElementById('msgs').innerHTML='';
    document.getElementById('msgs').style.display='none';
    document.getElementById('welcome').style.display='flex';
    document.getElementById('files').innerHTML='';
    loadConvs();
}

async function send(){
    const inp=document.getElementById('input');
    const msg=inp.value.trim();
    if(!msg||streaming)return;
    
    document.getElementById('welcome').style.display='none';
    document.getElementById('msgs').style.display='block';
    
    addMsg('user',msg);
    hist.push({role:'user',content:msg});
    inp.value='';
    inp.style.height='auto';
    
    streaming=true;
    document.getElementById('send').disabled=true;
    
    const typingId=addTyping();
    
    try{
        const r=await fetch('/api/chat',{
            method:'POST',
            headers:{'Content-Type':'application/json'},
            body:JSON.stringify({message:msg,model,conversation_id:convId,language:'en'})
        });
        
        removeTyping(typingId);
        const msgId=addMsg('assistant','');
        let full='';
        
        const reader=r.body.getReader();
        const decoder=new TextDecoder();
        
        while(true){
            const{done,value}=await reader.read();
            if(done)break;
            
            const chunk=decoder.decode(value);
            const lines=chunk.split('\n');
            
            for(const line of lines){
                if(line.startsWith('data: ')){
                    try{
                        const data=JSON.parse(line.slice(6));
                        if(data.content){
                            full+=data.content;
                            updateMsg(msgId,full);
                            scroll();
                        }
                        if(data.done){
                            hist.push({role:'assistant',content:full});
                            await saveConv();
                            await loadConvs();
                        }
                    }catch(e){}
                }
            }
        }
        
        files=[];
        document.getElementById('files').innerHTML='';
    }catch(e){
        removeTyping(typingId);
        addMsg('assistant','Error. Make sure Ollama is running.');
    }finally{
        streaming=false;
        document.getElementById('send').disabled=false;
        inp.focus();
    }
}

function addMsg(role,content){
    const msgs=document.getElementById('msgs');
    const id=`msg-${Date.now()}`;
    const div=document.createElement('div');
    div.className=`message ${role}`;
    div.id=id;
    const icon=role==='user'?'<i class="fas fa-user"></i>':'<i class="fas fa-robot"></i>';
    const name=role==='user'?'You':'ChatGPT';
    div.innerHTML=`<div class="msg-header"><div class="msg-icon">${icon}</div><span>${name}</span></div><div class="msg-content">${formatMsg(content)}</div>`;
    msgs.appendChild(div);
    scroll();
    return id;
}

function updateMsg(id,content){
    const msg=document.getElementById(id);
    if(msg){
        msg.querySelector('.msg-content').innerHTML=formatMsg(content);
    }
}

function formatMsg(c){
    if(!c)return '';
    let f=c.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    f=f.replace(/```(\w+)?\n([\s\S]*?)```/g,(m,l,code)=>`<pre><code>${code.trim()}</code></pre>`);
    f=f.replace(/`([^`]+)`/g,'<code>$1</code>');
    f=f.replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');
    return f;
}

function addTyping(){
    const msgs=document.getElementById('msgs');
    const id=`typing-${Date.now()}`;
    const div=document.createElement('div');
    div.className='message assistant';
    div.id=id;
    div.innerHTML='<div class="msg-header"><div class="msg-icon"><i class="fas fa-robot"></i></div><span>ChatGPT</span></div><div class="typing"><div></div><div></div><div></div></div>';
    msgs.appendChild(div);
    scroll();
    return id;
}

function removeTyping(id){
    const t=document.getElementById(id);
    if(t)t.remove();
}

function scroll(){
    const chat=document.getElementById('chat');
    chat.scrollTop=chat.scrollHeight;
}

function handleKey(e){
    if(e.key==='Enter'&&!e.shiftKey){
        e.preventDefault();
        send();
    }
}

function autoResize(){
    const inp=document.getElementById('input');
    inp.addEventListener('input',function(){
        this.style.height='auto';
        this.style.height=Math.min(this.scrollHeight,200)+'px';
    });
}

async function handleFile(e){
    const fs=e.target.files;
    for(const f of fs){
        const fd=new FormData();
        fd.append('file',f);
        fd.append('conversation_id',convId||'');
        try{
            const r=await fetch('/api/upload',{method:'POST',body:fd});
            const d=await r.json();
            if(d.success){
                files.push(d);
                displayFile(d);
            }
        }catch(e){console.error(e)}
    }
    e.target.value='';
}

function displayFile(f){
    const cont=document.getElementById('files');
    const tag=document.createElement('div');
    tag.className='file-tag';
    tag.innerHTML=`<i class="fas fa-file"></i><span>${f.filename}</span>`;
    cont.appendChild(tag);
}

async function startVoice(){
    if(!navigator.mediaDevices)return;
    try{
        const stream=await navigator.mediaDevices.getUserMedia({audio:true});
        mediaRecorder=new MediaRecorder(stream);
        audioChunks=[];
        
        mediaRecorder.ondataavailable=e=>audioChunks.push(e.data);
        mediaRecorder.onstop=async()=>{
            const blob=new Blob(audioChunks,{type:'audio/webm'});
            const fd=new FormData();
            fd.append('audio',blob,'voice.webm');
            fd.append('conversation_id',convId||'');
            
            try{
                const r=await fetch('/api/transcribe',{method:'POST',body:fd});
                const d=await r.json();
                if(d.transcription){
                    document.getElementById('input').value=d.transcription;
                }
            }catch(e){console.error(e)}
            
            stream.getTracks().forEach(t=>t.stop());
        };
        
        mediaRecorder.start();
        document.getElementById('voice').classList.add('recording');
    }catch(e){console.error(e)}
}

function stopVoice(){
    if(mediaRecorder&&mediaRecorder.state==='recording'){
        mediaRecorder.stop();
        document.getElementById('voice').classList.remove('recording');
    }
}

function changeModel(){
    model=document.getElementById('model').value;
}

function toggleSidebar(){
    document.getElementById('sidebar').classList.toggle('active');
}

document.getElementById('input').addEventListener('input',function(){
    document.getElementById('send').disabled=!this.value.trim();
});
JS

echo "✅ Complete UI created"
