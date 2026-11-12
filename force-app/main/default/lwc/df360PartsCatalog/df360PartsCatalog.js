import { LightningElement, api, track } from 'lwc';
import searchParts from '@salesforce/apex/DF360_PartsController.searchParts';
import raisePartsRequest from '@salesforce/apex/DF360_PartsController.raisePartsRequest';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360PartsCatalog extends LightningElement {
    @api recordId;
    @track searchTerm = '';
    @track parts = [];

    connectedCallback() {
        this.doSearch();
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    async doSearch() {
        try {
            this.parts = await searchParts({ searchTerm: this.searchTerm, category: null });
        } catch(e) {
            console.error(e);
        }
    }

    async handleRequestPart(event) {
        const partId = event.target.dataset.id;
        if (!this.recordId) {
            this.showToast('Note', 'Parts request created in stock system', 'info');
            return;
        }
        try {
            await raisePartsRequest({ jobId: this.recordId, partId: partId, qty: 1 });
            this.showToast('Success', 'Parts request submitted for job', 'success');
        } catch(e) {
            this.showToast('Error', e.body?.message || 'Request failed', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
