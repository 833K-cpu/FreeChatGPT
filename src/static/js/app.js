// FreeChatGPT - Main Application
// By: 833K-cpu

// State management
let currentConversationId = null;
let conversations = [];
let conversationHistory = [];
let currentModel = 'llama3.2:3b';
let isStreaming = false;
let uploadedFiles = [];

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
});

async function initializeApp() {
    await checkSystemStatus();
    await loadConversations();
    autoResizeTextarea();
    
    // Auto-check status every 30 seconds
    setInterval(checkSystemStatus, 30000);
    
    // Auto-save conversation every 30 seconds
    setInterval(saveCurrentConversation, 30000);
}

// System Status
async function checkSystemStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();
        
        const statusIndicator = document.getElementById('statusIndicator');
        const statusText = document.getElementById('statusText');
        
        if (data.ollama_running) {
            statusIndicator.className = 'status-indicator online';
            statusText.textContent = 'Online';
            updateModelSelector(data.available_models, data.recommended_models);
        } else {
            statusIndicator.className = 'status-indicator offline';
            statusText.textContent = 'Offline';
        }
        
        updateSystemInfo(data);
        
    } catch (error) {
        console.error('Status check failed:', error);
        document.getElementById('statusIndicator').className = 'status-indicator offline';
        document.getElementById('statusText').textContent = 'Error';
    }
}

// Model Management
function updateModelSelector(availableModels, recommendedModels) {
    const modelSelect = document.getElementById('modelSelect');
    modelSelect.innerHTML = '';
    
    if (availableModels.length === 0) {
        const option = document.createElement('option');
        option.value = '';
        option.textContent = 'No models installed';
        modelSelect.appendChild(option);
        return;
    }
    
    availableModels.forEach(model => {
        const option = document.createElement('option');
        option.value = model;
        
        if (recommendedModels[model]) {
            const info = recommendedModels[model];
            option.textContent = `${info.name} - ${info.category}`;
        } else {
            option.textContent = model;
        }
        
        modelSelect.appendChild(option);
    });
    
    modelSelect.value = currentModel;
}

function changeModel() {
    const select = document.getElementById('modelSelect');
    currentModel = select.value;
    console.log('Model changed to:', currentModel);
}

// Conversation Management
async function loadConversations() {
    try {
        const response = await fetch('/api/conversations');
        const data = await response.json();
        conversations = data.conversations || [];
        
        renderConversationTabs();
        
        // Load most recent conversation if exists
        if (conversations.length > 0 && !currentConversationId) {
            await loadConversation(conversations[0].id);
        }
    } catch (error) {
        console.error('Failed to load conversations:', error);
    }
}

function renderConversationTabs() {
    const container = document.getElementById('conversationTabs');
    container.innerHTML = '<div class="tab-section-title">Conversations</div>';
    
    conversations.forEach(conv => {
        const tab = document.createElement('div');
        tab.className = 'conversation-tab';
        if (conv.id === currentConversationId) {
            tab.classList.add('active');
        }
        
        tab.innerHTML = `
            <span>${conv.title}</span>
            <i class="fas fa-trash" onclick="deleteConversation('${conv.id}', event)" style="font-size: 12px; opacity: 0.5;"></i>
        `;
        
        tab.onclick = (e) => {
            if (!e.target.classList.contains('fa-trash')) {
                loadConversation(conv.id);
            }
        };
        
        container.appendChild(tab);
    });
}

async function loadConversation(conversationId) {
    try {
        const response = await fetch(`/api/conversations/${conversationId}`);
        const data = await response.json();
        
        currentConversationId = conversationId;
        conversationHistory = data.messages || [];
        
        document.getElementById('welcomeScreen').style.display = 'none';
        document.getElementById('messagesContainer').style.display = 'block';
        document.getElementById('messagesContainer').innerHTML = '';
        
        conversationHistory.forEach(msg => {
            addMessage(msg.role, msg.content);
        });
        
        renderConversationTabs();
        
    } catch (error) {
        console.error('Failed to load conversation:', error);
    }
}

async function saveCurrentConversation() {
    if (!currentConversationId || conversationHistory.length === 0) return;
    
    const autoSave = document.getElementById('autoSave')?.checked !== false;
    if (!autoSave) return;
    
    try {
        const title = conversationHistory[0]?.content?.substring(0, 50) || 'Untitled Chat';
        const data = {
            id: currentConversationId,
            title: title,
            timestamp: Date.now(),
            messages: conversationHistory
        };
        
        await fetch(`/api/conversations/${currentConversationId}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        
    } catch (error) {
        console.error('Failed to save conversation:', error);
    }
}

async function deleteConversation(conversationId, event) {
    event.stopPropagation();
    
    if (!confirm('Delete this conversation?')) return;
    
    try {
        await fetch(`/api/conversations/${conversationId}`, { method: 'DELETE' });
        
        if (conversationId === currentConversationId) {
            newChat();
        }
        
        await loadConversations();
        
    } catch (error) {
        console.error('Failed to delete conversation:', error);
    }
}

// Chat Functions
function newChat() {
    currentConversationId = `chat_${Date.now()}`;
    conversationHistory = [];
    uploadedFiles = [];
    
    document.getElementById('messagesContainer').innerHTML = '';
    document.getElementById('messagesContainer').style.display = 'none';
    document.getElementById('welcomeScreen').style.display = 'flex';
    document.getElementById('attachedFiles').innerHTML = '';
    
    renderConversationTabs();
}

async function sendMessage() {
    const input = document.getElementById('messageInput');
    const message = input.value.trim();
    
    if (!message || isStreaming) return;
    
    // Hide welcome screen, show messages
    document.getElementById('welcomeScreen').style.display = 'none';
    document.getElementById('messagesContainer').style.display = 'block';
    
    // Add user message
    addMessage('user', message);
    conversationHistory.push({ role: 'user', content: message });
    
    // Clear input
    input.value = '';
    input.style.height = 'auto';
    
    // Disable send button
    isStreaming = true;
    document.getElementById('sendBtn').disabled = true;
    
    // Add typing indicator
    const typingId = addTypingIndicator();
    
    try {
        const response = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                message: message,
                model: currentModel,
                history: conversationHistory,
                files: uploadedFiles
            })
        });
        
        removeTypingIndicator(typingId);
        
        const messageId = addMessage('assistant', '');
        let fullResponse = '';
        
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            const chunk = decoder.decode(value);
            const lines = chunk.split('\n');
            
            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    try {
                        const data = JSON.parse(line.slice(6));
                        
                        if (data.content) {
                            fullResponse += data.content;
                            updateMessage(messageId, fullResponse);
                            scrollToBottom();
                        }
                        
                        if (data.done) {
                            conversationHistory.push({ role: 'assistant', content: fullResponse });
                            await saveCurrentConversation();
                            await loadConversations();
                        }
                        
                        if (data.error) {
                            updateMessage(messageId, `Error: ${data.error}`);
                        }
                    } catch (e) {
                        // Ignore parse errors
                    }
                }
            }
        }
        
        // Clear uploaded files after sending
        uploadedFiles = [];
        document.getElementById('attachedFiles').innerHTML = '';
        
    } catch (error) {
        console.error('Error sending message:', error);
        removeTypingIndicator(typingId);
        addMessage('assistant', 'Sorry, there was an error. Please ensure Ollama is running.');
    } finally {
        isStreaming = false;
        document.getElementById('sendBtn').disabled = false;
        input.focus();
    }
}

// File Upload
async function handleFileSelect(event) {
    const files = event.target.files;
    
    for (const file of files) {
        const formData = new FormData();
        formData.append('file', file);
        
        try {
            const response = await fetch('/api/upload', {
                method: 'POST',
                body: formData
            });
            
            const data = await response.json();
            
            if (data.success) {
                uploadedFiles.push(data);
                displayAttachedFile(data);
            } else {
                alert(`Failed to upload ${file.name}: ${data.error}`);
            }
        } catch (error) {
            console.error('Upload error:', error);
            alert(`Failed to upload ${file.name}`);
        }
    }
    
    event.target.value = '';
}

function displayAttachedFile(fileData) {
    const container = document.getElementById('attachedFiles');
    
    const fileTag = document.createElement('div');
    fileTag.className = 'attached-file';
    fileTag.innerHTML = `
        <i class="fas fa-file"></i>
        <span>${fileData.filename}</span>
        <i class="fas fa-times" onclick="removeAttachedFile('${fileData.filepath}')" style="cursor: pointer; margin-left: 4px;"></i>
    `;
    
    container.appendChild(fileTag);
}

function removeAttachedFile(filepath) {
    uploadedFiles = uploadedFiles.filter(f => f.filepath !== filepath);
    renderAttachedFiles();
}

function renderAttachedFiles() {
    const container = document.getElementById('attachedFiles');
    container.innerHTML = '';
    uploadedFiles.forEach(file => displayAttachedFile(file));
}

// VirusTotal Functions
async function handleVTFileSelect(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const apiKey = document.getElementById('vtApiKey').value.trim();
    if (!apiKey) {
        alert('Please enter your VirusTotal API key first');
        return;
    }
    
    const resultsDiv = document.getElementById('vtResults');
    resultsDiv.style.display = 'block';
    resultsDiv.innerHTML = '<p>Uploading file for scanning...</p>';
    
    const formData = new FormData();
    formData.append('file', file);
    formData.append('api_key', apiKey);
    
    try {
        const response = await fetch('/api/virustotal/upload', {
            method: 'POST',
            body: formData
        });
        
        const data = await response.json();
        
        if (data.success) {
            resultsDiv.innerHTML = `
                <div style="padding: 20px; background-color: var(--bg-secondary); border-radius: 12px;">
                    <h3>✓ File uploaded successfully</h3>
                    <p>Scan ID: ${data.scan_id}</p>
                    <p>Results will be available shortly. Check back in a few moments.</p>
                </div>
            `;
        } else {
            resultsDiv.innerHTML = `<p style="color: #ef4444;">Error: ${data.error}</p>`;
        }
    } catch (error) {
        resultsDiv.innerHTML = `<p style="color: #ef4444;">Upload failed: ${error.message}</p>`;
    }
    
    event.target.value = '';
}

// UI Helper Functions
function addMessage(role, content) {
    const container = document.getElementById('messagesContainer');
    const messageId = `msg-${Date.now()}`;
    
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;
    messageDiv.id = messageId;
    
    const icon = role === 'user' ? '<i class="fas fa-user"></i>' : '<i class="fas fa-robot"></i>';
    const name = role === 'user' ? 'You' : 'FreeChatGPT';
    
    messageDiv.innerHTML = `
        <div class="message-header">
            <div class="message-icon">${icon}</div>
            <span>${name}</span>
        </div>
        <div class="message-content">${formatMessage(content)}</div>
    `;
    
    container.appendChild(messageDiv);
    scrollToBottom();
    
    return messageId;
}

function updateMessage(messageId, content) {
    const message = document.getElementById(messageId);
    if (message) {
        const contentDiv = message.querySelector('.message-content');
        contentDiv.innerHTML = formatMessage(content);
    }
}

function formatMessage(content) {
    if (!content) return '';
    
    let formatted = content
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
    
    formatted = formatted.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
        return `<pre><code>${code.trim()}</code></pre>`;
    });
    
    formatted = formatted.replace(/`([^`]+)`/g, '<code>$1</code>');
    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    formatted = formatted.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');
    
    return formatted;
}

function addTypingIndicator() {
    const container = document.getElementById('messagesContainer');
    const indicatorId = `typing-${Date.now()}`;
    
    const div = document.createElement('div');
    div.className = 'message assistant';
    div.id = indicatorId;
    div.innerHTML = `
        <div class="message-header">
            <div class="message-icon"><i class="fas fa-robot"></i></div>
            <span>FreeChatGPT</span>
        </div>
        <div class="typing-indicator">
            <div class="typing-dot"></div>
            <div class="typing-dot"></div>
            <div class="typing-dot"></div>
        </div>
    `;
    
    container.appendChild(div);
    scrollToBottom();
    
    return indicatorId;
}

function removeTypingIndicator(indicatorId) {
    const indicator = document.getElementById(indicatorId);
    if (indicator) indicator.remove();
}

function scrollToBottom() {
    const container = document.getElementById('chatContainer');
    container.scrollTop = container.scrollHeight;
}

function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
    }
}

function autoResizeTextarea() {
    const textarea = document.getElementById('messageInput');
    
    textarea.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.min(this.scrollHeight, 200) + 'px';
    });
}

function sendQuickPrompt(prompt) {
    const input = document.getElementById('messageInput');
    input.value = prompt;
    sendMessage();
}

// Tab Navigation
function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.nav-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    event.target.closest('.nav-tab').classList.add('active');
    
    // Update tab content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById(`${tabName}Tab`).classList.add('active');
}

// Settings
function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    sidebar.classList.toggle('active');
}

function toggleSettings() {
    const modal = document.getElementById('settingsModal');
    modal.classList.toggle('active');
    
    if (modal.classList.contains('active')) {
        checkSystemStatus();
    }
}

function updateSystemInfo(data) {
    const ollamaStatus = document.getElementById('ollamaStatus');
    const installedModels = document.getElementById('installedModels');
    
    if (ollamaStatus) {
        ollamaStatus.textContent = data.ollama_running ? 'Running ✓' : 'Not Running ✗';
        ollamaStatus.style.color = data.ollama_running ? 'var(--accent-color)' : '#ef4444';
    }
    
    if (installedModels) {
        installedModels.textContent = data.available_models.length > 0 
            ? data.available_models.join(', ') 
            : 'None';
    }
}

function changeTheme() {
    const theme = document.getElementById('themeSelect').value;
    document.body.className = theme === 'dark' ? 'dark-theme' : 'light-theme';
    localStorage.setItem('theme', theme);
}

async function clearAllConversations() {
    if (!confirm('Delete all conversations? This cannot be undone.')) return;
    
    for (const conv of conversations) {
        await fetch(`/api/conversations/${conv.id}`, { method: 'DELETE' });
    }
    
    conversations = [];
    newChat();
    renderConversationTabs();
}

// Model Manager
function showModelManager() {
    const modal = document.getElementById('modelManagerModal');
    modal.classList.add('active');
    loadModelList();
}

function closeModelManager() {
    const modal = document.getElementById('modelManagerModal');
    modal.classList.remove('active');
}

async function loadModelList() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();
        
        const modelList = document.getElementById('modelList');
        modelList.innerHTML = '';
        
        const recommended = data.recommended_models || {};
        
        for (const [modelName, modelInfo] of Object.entries(recommended)) {
            const isInstalled = data.available_models.includes(modelName);
            
            const modelCard = document.createElement('div');
            modelCard.style.cssText = 'padding: 16px; background-color: var(--bg-input); border-radius: 12px; margin-bottom: 12px;';
            modelCard.innerHTML = `
                <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 12px;">
                    <div>
                        <h4 style="margin-bottom: 6px;">${modelInfo.name}</h4>
                        <p style="font-size: 13px; color: var(--text-secondary); margin-bottom: 8px;">${modelInfo.description}</p>
                        <div style="display: flex; gap: 12px; font-size: 12px; color: var(--text-tertiary);">
                            <span><i class="fas fa-database"></i> ${modelInfo.size}</span>
                            <span><i class="fas fa-memory"></i> ${modelInfo.vram}</span>
                            <span><i class="fas fa-tag"></i> ${modelInfo.category}</span>
                        </div>
                    </div>
                    <button 
                        onclick="pullModel('${modelName}')" 
                        ${isInstalled ? 'disabled' : ''}
                        style="padding: 10px 18px; background-color: ${isInstalled ? 'var(--border-color)' : 'var(--accent-color)'}; border: none; border-radius: 8px; color: white; cursor: ${isInstalled ? 'not-allowed' : 'pointer'}; font-weight: 500; font-size: 13px;"
                    >
                        ${isInstalled ? '✓ Installed' : 'Download'}
                    </button>
                </div>
            `;
            modelList.appendChild(modelCard);
        }
        
    } catch (error) {
        console.error('Failed to load models:', error);
    }
}

async function pullModel(modelName) {
    alert(`Downloading ${modelName}...\n\nThis may take several minutes. Check your terminal for progress.`);
    
    try {
        const response = await fetch('/api/pull-model', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ model: modelName })
        });
        
        // Could implement progress tracking here
        
    } catch (error) {
        console.error('Failed to pull model:', error);
        alert('Download failed. Check console for details.');
    }
}

function filterModels(category) {
    document.querySelectorAll('.category-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
    
    // Filtering logic could be implemented here
    loadModelList();
}

// Image Generation (placeholder)
async function generateImage() {
    const prompt = document.getElementById('imgPrompt').value.trim();
    if (!prompt) {
        alert('Please enter a prompt');
        return;
    }
    
    const resultDiv = document.getElementById('imgGenResult');
    resultDiv.innerHTML = '<p>This feature requires local Stable Diffusion setup.<br>See documentation for installation instructions.</p>';
}

// Close modals on outside click
window.onclick = function(event) {
    const settingsModal = document.getElementById('settingsModal');
    const modelModal = document.getElementById('modelManagerModal');
    
    if (event.target === settingsModal) {
        settingsModal.classList.remove('active');
    }
    if (event.target === modelModal) {
        modelModal.classList.remove('active');
    }
}

// Load theme on start
const savedTheme = localStorage.getItem('theme');
if (savedTheme) {
    document.body.className = savedTheme === 'dark' ? 'dark-theme' : 'light-theme';
}
