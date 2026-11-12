import { LightningElement, api, track } from 'lwc';
import askGuruAI from '@salesforce/apex/DF360_GuruAIController.askGuruAI';

export default class Df360GuruAI extends LightningElement {
    @api recordId; // Optional Service Job / Work Order Id
    @track inputMsg = '';
    @track isLoading = false;
    @track messages = [
        { 
            id: '1', 
            sender: 'GuruAI Copilot', 
            time: 'Just now',
            text: 'Hello! I am your digiField360 Agentforce diagnostic copilot. Ask me any machinery diagnostic questions, error code procedures (e.g., E-401), or parts requirements.', 
            isStructured: false,
            containerClass: 'msg-row ai-row',
            bubbleClass: 'msg-bubble ai-bubble' 
        }
    ];

    handleInputChange(event) {
        this.inputMsg = event.target.value;
    }

    handleKeyUp(event) {
        if (event.keyCode === 13) {
            this.handleSend();
        }
    }

    handleQuickPrompt(event) {
        const prompt = event.target.dataset.prompt;
        if (prompt) {
            this.inputMsg = prompt;
            this.handleSend();
        }
    }

    formatTime() {
        const d = new Date();
        return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    async handleSend() {
        if (!this.inputMsg || !this.inputMsg.trim() || this.isLoading) return;
        const q = this.inputMsg.trim();
        const timeNow = this.formatTime();

        this.messages = [
            ...this.messages,
            { 
                id: String(Date.now()), 
                sender: 'You', 
                time: timeNow,
                text: q, 
                isStructured: false,
                containerClass: 'msg-row user-row',
                bubbleClass: 'msg-bubble user-bubble' 
            }
        ];
        this.inputMsg = '';
        this.isLoading = true;

        try {
            const rawReply = await askGuruAI({ technicianId: null, jobId: this.recordId, message: q });
            let isStructured = false;
            let structuredObj = null;

            if (rawReply && typeof rawReply === 'string' && rawReply.trim().startsWith('{')) {
                try {
                    const parsed = JSON.parse(rawReply);
                    if (parsed && (parsed.actionableSteps || parsed.safetyPrecautions || parsed.recommendedParts)) {
                        isStructured = true;
                        structuredObj = parsed;
                    }
                } catch (pe) {
                    // Not valid JSON, keep as plain text
                }
            }

            this.messages = [
                ...this.messages,
                { 
                    id: String(Date.now() + 1), 
                    sender: 'GuruAI Copilot', 
                    time: this.formatTime(),
                    text: rawReply,
                    isStructured: isStructured,
                    structured: structuredObj,
                    containerClass: 'msg-row ai-row',
                    bubbleClass: 'msg-bubble ai-bubble' 
                }
            ];
        } catch (e) {
            console.error('GuruAI Apex error:', e);
            this.messages = [
                ...this.messages,
                { 
                    id: String(Date.now() + 1), 
                    sender: 'GuruAI Copilot', 
                    time: this.formatTime(),
                    text: '⚠️ Diagnostic Service Notice: ' + (e.body?.message || e.message || 'Error processing diagnostic request.'), 
                    isStructured: false,
                    containerClass: 'msg-row ai-row',
                    bubbleClass: 'msg-bubble ai-bubble' 
                }
            ];
        } finally {
            this.isLoading = false;
            this.scrollToBottom();
        }
    }

    scrollToBottom() {
        setTimeout(() => {
            const chatBox = this.template.querySelector('.chat-window');
            if (chatBox) {
                chatBox.scrollTop = chatBox.scrollHeight;
            }
        }, 100);
    }
}
