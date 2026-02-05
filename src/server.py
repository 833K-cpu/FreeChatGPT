#!/usr/bin/env python3
"""
FreeChatGPT - Your Personal AI, Completely Free
By: 833K-cpu
Optimized for GTX 2060 (6GB VRAM) + Ryzen 5 2600 + 16GB RAM
"""

from flask import Flask, render_template, request, jsonify, Response, stream_with_context, send_from_directory
import requests
import json
import os
import logging
from datetime import datetime
import base64
import hashlib
from werkzeug.utils import secure_filename
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['SECRET_KEY'] = os.urandom(24)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max file size
app.config['UPLOAD_FOLDER'] = 'src/static/uploads'

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Configuration optimized for GTX 2060
OLLAMA_API_URL = "http://localhost:11434"
VIRUSTOTAL_API_KEY = ""  # User will add their own key

# Model configurations for different use cases
RECOMMENDED_MODELS = {
    "llama3.2:3b": {
        "name": "Llama 3.2 3B",
        "category": "General",
        "size": "2GB",
        "description": "Best all-rounder - conversation, research, coding",
        "vram": "~3GB",
        "use_cases": ["conversation", "research", "coding", "general"]
    },
    "mistral:7b": {
        "name": "Mistral 7B (4-bit)",
        "category": "Creative",
        "size": "4.1GB",
        "description": "Creative writing, storytelling, detailed responses",
        "vram": "~5GB",
        "use_cases": ["creative", "writing", "storytelling"]
    },
    "llama3.2-vision:11b": {
        "name": "Llama 3.2 Vision",
        "category": "Vision",
        "size": "7.9GB",
        "description": "Analyze images and documents (CPU fallback)",
        "vram": "CPU",
        "use_cases": ["vision", "image-analysis", "document"]
    },
    "qwen2.5:3b": {
        "name": "Qwen 2.5 3B",
        "category": "Fast",
        "size": "1.9GB",
        "description": "Ultra-fast responses, multilingual",
        "vram": "~3GB",
        "use_cases": ["quick", "multilingual", "fast"]
    }
}

ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'doc', 'docx'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def check_ollama_status():
    """Check if Ollama service is running"""
    try:
        response = requests.get(f"{OLLAMA_API_URL}/api/tags", timeout=5)
        return response.status_code == 200
    except:
        return False

def get_available_models():
    """Get list of installed Ollama models"""
    try:
        response = requests.get(f"{OLLAMA_API_URL}/api/tags")
        if response.status_code == 200:
            models_data = response.json()
            return [model['name'] for model in models_data.get('models', [])]
        return []
    except Exception as e:
        logger.error(f"Error fetching models: {e}")
        return []

@app.route('/')
def index():
    """Serve the main ChatGPT-like interface"""
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    """Check system status"""
    ollama_running = check_ollama_status()
    available_models = get_available_models() if ollama_running else []
    
    return jsonify({
        'ollama_running': ollama_running,
        'available_models': available_models,
        'recommended_models': RECOMMENDED_MODELS,
        'default_model': 'llama3.2:3b'
    })

@app.route('/api/chat', methods=['POST'])
def chat():
    """Handle chat messages with streaming response"""
    data = request.json
    message = data.get('message', '')
    model = data.get('model', 'llama3.2:3b')
    conversation_history = data.get('history', [])
    uploaded_files = data.get('files', [])
    
    if not message:
        return jsonify({'error': 'No message provided'}), 400
    
    # Build context from history
    messages = []
    for msg in conversation_history[-10:]:
        messages.append({
            'role': msg['role'],
            'content': msg['content']
        })
    
    # Add current message with file context if any
    current_content = message
    if uploaded_files:
        current_content += f"\n\n[User uploaded {len(uploaded_files)} file(s)]"
    
    messages.append({
        'role': 'user',
        'content': current_content
    })
    
    # Stream response from Ollama
    def generate():
        try:
            response = requests.post(
                f"{OLLAMA_API_URL}/api/chat",
                json={
                    'model': model,
                    'messages': messages,
                    'stream': True,
                    'options': {
                        'temperature': 0.7,
                        'num_ctx': 4096,
                        'num_predict': 2048,
                        'num_gpu': 1
                    }
                },
                stream=True,
                timeout=300
            )
            
            for line in response.iter_lines():
                if line:
                    chunk = json.loads(line)
                    if 'message' in chunk:
                        content = chunk['message'].get('content', '')
                        if content:
                            yield f"data: {json.dumps({'content': content})}\n\n"
                    
                    if chunk.get('done', False):
                        yield f"data: {json.dumps({'done': True})}\n\n"
                        
        except Exception as e:
            logger.error(f"Error during chat: {e}")
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
    
    return Response(
        stream_with_context(generate()),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no'
        }
    )

@app.route('/api/upload', methods=['POST'])
def upload_file():
    """Handle file uploads"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        unique_filename = f"{uuid.uuid4()}_{filename}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], unique_filename)
        file.save(filepath)
        
        # Get file info
        file_size = os.path.getsize(filepath)
        file_type = filename.rsplit('.', 1)[1].lower()
        
        return jsonify({
            'success': True,
            'filename': filename,
            'filepath': unique_filename,
            'size': file_size,
            'type': file_type
        })
    
    return jsonify({'error': 'Invalid file type'}), 400

@app.route('/api/virustotal/scan', methods=['POST'])
def virustotal_scan():
    """Scan file with VirusTotal (no download)"""
    data = request.json
    file_hash = data.get('hash')
    api_key = data.get('api_key', VIRUSTOTAL_API_KEY)
    
    if not api_key:
        return jsonify({'error': 'VirusTotal API key required'}), 400
    
    if not file_hash:
        return jsonify({'error': 'File hash required'}), 400
    
    try:
        # Check if file already scanned
        url = f"https://www.virustotal.com/api/v3/files/{file_hash}"
        headers = {'x-apikey': api_key}
        
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            return jsonify({
                'success': True,
                'scan_results': data['data']['attributes']['last_analysis_stats'],
                'scan_date': data['data']['attributes']['last_analysis_date'],
                'file_info': {
                    'size': data['data']['attributes'].get('size'),
                    'type': data['data']['attributes'].get('type_description'),
                    'names': data['data']['attributes'].get('names', [])
                }
            })
        else:
            return jsonify({
                'success': False,
                'error': 'File not found in VirusTotal database',
                'message': 'Upload file for scanning'
            })
            
    except Exception as e:
        logger.error(f"VirusTotal error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/virustotal/upload', methods=['POST'])
def virustotal_upload():
    """Upload file to VirusTotal for scanning"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    api_key = request.form.get('api_key', VIRUSTOTAL_API_KEY)
    
    if not api_key:
        return jsonify({'error': 'VirusTotal API key required'}), 400
    
    try:
        url = 'https://www.virustotal.com/api/v3/files'
        headers = {'x-apikey': api_key}
        files = {'file': (file.filename, file.stream, file.content_type)}
        
        response = requests.post(url, headers=headers, files=files)
        
        if response.status_code == 200:
            data = response.json()
            return jsonify({
                'success': True,
                'scan_id': data['data']['id'],
                'message': 'File uploaded for scanning. Results will be available shortly.'
            })
        else:
            return jsonify({'error': 'Upload failed', 'details': response.text}), 500
            
    except Exception as e:
        logger.error(f"VirusTotal upload error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/generate-image', methods=['POST'])
def generate_image():
    """Generate image using Stable Diffusion (placeholder for now)"""
    data = request.json
    prompt = data.get('prompt', '')
    
    if not prompt:
        return jsonify({'error': 'No prompt provided'}), 400
    
    # This is a placeholder - user needs to set up Stable Diffusion locally
    return jsonify({
        'success': False,
        'message': 'Image generation requires local Stable Diffusion setup',
        'instructions': 'Install stable-diffusion-webui and enable API mode'
    })

@app.route('/api/conversations', methods=['GET'])
def get_conversations():
    """Get saved conversations list"""
    conversations_dir = 'data/conversations'
    os.makedirs(conversations_dir, exist_ok=True)
    
    conversations = []
    for filename in os.listdir(conversations_dir):
        if filename.endswith('.json'):
            filepath = os.path.join(conversations_dir, filename)
            with open(filepath, 'r') as f:
                conv_data = json.load(f)
                conversations.append({
                    'id': filename.replace('.json', ''),
                    'title': conv_data.get('title', 'Untitled Chat'),
                    'timestamp': conv_data.get('timestamp'),
                    'message_count': len(conv_data.get('messages', []))
                })
    
    return jsonify({'conversations': sorted(conversations, key=lambda x: x['timestamp'], reverse=True)})

@app.route('/api/conversations/<conversation_id>', methods=['GET', 'POST', 'DELETE'])
def manage_conversation(conversation_id):
    """Manage individual conversation"""
    conversations_dir = 'data/conversations'
    os.makedirs(conversations_dir, exist_ok=True)
    filepath = os.path.join(conversations_dir, f"{conversation_id}.json")
    
    if request.method == 'GET':
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                return jsonify(json.load(f))
        return jsonify({'error': 'Conversation not found'}), 404
    
    elif request.method == 'POST':
        data = request.json
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        return jsonify({'success': True})
    
    elif request.method == 'DELETE':
        if os.path.exists(filepath):
            os.remove(filepath)
            return jsonify({'success': True})
        return jsonify({'error': 'Conversation not found'}), 404

@app.route('/api/models')
def list_models():
    """Get available models"""
    available = get_available_models()
    return jsonify({
        'installed': available,
        'recommended': RECOMMENDED_MODELS
    })

@app.route('/api/pull-model', methods=['POST'])
def pull_model():
    """Pull a new model from Ollama"""
    data = request.json
    model_name = data.get('model')
    
    if not model_name:
        return jsonify({'error': 'No model specified'}), 400
    
    def generate():
        try:
            response = requests.post(
                f"{OLLAMA_API_URL}/api/pull",
                json={'name': model_name},
                stream=True,
                timeout=3600
            )
            
            for line in response.iter_lines():
                if line:
                    chunk = json.loads(line)
                    yield f"data: {json.dumps(chunk)}\n\n"
                    
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
    
    return Response(
        stream_with_context(generate()),
        mimetype='text/event-stream'
    )

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'ollama_connected': check_ollama_status()
    })

if __name__ == '__main__':
    print("""
    ╔══════════════════════════════════════════════════════════════╗
    ║                      FreeChatGPT                             ║
    ║           Your Personal AI, Completely Free                  ║
    ║                                                              ║
    ║  By: 833K-cpu                                               ║
    ║  Optimized for: GTX 2060 + Ryzen 5 2600 + 16GB RAM         ║
    ║                                                              ║
    ║  Server running at: http://localhost:5000                   ║
    ║  API available at:  http://localhost:5000/api/*             ║
    ║                                                              ║
    ║  Press Ctrl+C to stop the server                            ║
    ╚══════════════════════════════════════════════════════════════╝
    """)
    
    # Create data directory
    os.makedirs('data/conversations', exist_ok=True)
    
    # Check Ollama status
    if check_ollama_status():
        print("✓ Ollama service detected")
        models = get_available_models()
        if models:
            print(f"✓ {len(models)} model(s) installed")
        else:
            print("⚠ No models installed. Run installation script.")
    else:
        print("✗ Ollama not running. Start with: ollama serve")
    
    print("\n")
    
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,
        threaded=True
    )
