import { LightningElement, track } from 'lwc';
import getPendingApprovals from '@salesforce/apex/DF360_PartsController.getPendingApprovals';
import approveRequest from '@salesforce/apex/DF360_PartsController.approveRequest';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360PartsApproval extends LightningElement {
    @track pendingRequests = [];

    connectedCallback() {
        this.loadRequests();
    }

    get hasPending() {
        return this.pendingRequests.length > 0;
    }

    async loadRequests() {
        try {
            this.pendingRequests = await getPendingApprovals();
        } catch(e) {
            console.error(e);
        }
    }

    async handleApprove(event) {
        const reqId = event.target.dataset.id;
        try {
            await approveRequest({ requestId: reqId, approved: true, reason: null });
            this.showToast('Approved', 'Parts request approved and reserved', 'success');
            this.loadRequests();
        } catch(e) {
            this.showToast('Error', e.body?.message || 'Approval failed', 'error');
        }
    }

    async handleReject(event) {
        const reqId = event.target.dataset.id;
        try {
            await approveRequest({ requestId: reqId, approved: false, reason: 'Budget constraint' });
            this.showToast('Rejected', 'Parts request rejected', 'info');
            this.loadRequests();
        } catch(e) {
            this.showToast('Error', e.body?.message || 'Rejection failed', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
