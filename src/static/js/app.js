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
