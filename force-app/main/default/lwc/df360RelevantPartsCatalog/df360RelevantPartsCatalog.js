import { LightningElement, api, track } from 'lwc';
import getApplicablePartsForWorkOrder from '@salesforce/apex/DF360_PartsController.getApplicablePartsForWorkOrder';
import raisePartsRequestForWorkOrder from '@salesforce/apex/DF360_PartsController.raisePartsRequestForWorkOrder';
import issuePart from '@salesforce/apex/DF360_PartsController.issuePart';
import consumePart from '@salesforce/apex/DF360_PartsController.consumePart';
import returnPart from '@salesforce/apex/DF360_PartsController.returnPart';
import searchParts from '@salesforce/apex/DF360_PartsController.searchParts';
import getWorkOrderPartsRequests from '@salesforce/apex/DF360_PartsController.getWorkOrderPartsRequests';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360RelevantPartsCatalog extends LightningElement {
    @api recordId; // Work_Order__c Id
    @track isLoading = false;
    @track activeRequests = [];
    @track applicableParts = [];
    @track showRequestModal = false;
    @track searchTerm = '';
    @track showAllCatalog = false;
    @track assetName = 'Equipment';
    @track assetModel = '';
    @track assetCategory = '';
    @track partQuantities = {};

    connectedCallback() {
        this.loadRequests();
    }

    get hasActiveRequests() {
        return this.activeRequests && this.activeRequests.length > 0;
    }

    get catalogModeLabel() {
        return this.showAllCatalog ? 'Switch to Relevant Parts Only' : 'Browse All Catalog';
    }

    get catalogSubtitle() {
        if (this.showAllCatalog) {
            return 'Browsing Complete Spare Parts Catalogue (Global Search Active)';
        }
        return `Showing parts applicable to ${this.assetName} (${this.assetModel || 'Standard'} — ${this.assetCategory || 'General'})`;
    }

    async loadRequests() {
        this.isLoading = true;
        try {
            const data = await getWorkOrderPartsRequests({ workOrderId: this.recordId });
            this.activeRequests = data.map(r => {
                let badge = 'slds-badge ';
                if (r.status === 'Approved') badge += 'slds-theme_success';
                else if (r.status === 'Pending Approval') badge += 'slds-theme_warning';
                else if (r.status === 'Part Issued') badge += 'slds-theme_alt-inverse';
                else if (r.status === 'Consumed') badge += 'slds-badge_lightest';
                else if (r.status === 'Returned') badge += 'slds-theme_inverse';

                return {
                    ...r,
                    statusBadgeClass: badge,
                    canIssue: r.status === 'Approved',
                    canConsume: r.status === 'Part Issued',
                    canReturn: r.status === 'Part Issued',
                    isConsumed: r.status === 'Consumed',
                    isReturned: r.status === 'Returned'
                };
            });
        } catch (error) {
            console.error('Error loading parts requests:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async openRequestModal() {
        this.showRequestModal = true;
        this.showAllCatalog = false;
        await this.loadApplicableParts();
    }

    closeRequestModal() {
        this.showRequestModal = false;
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        this.loadApplicableParts();
    }

    handleToggleCatalogMode() {
        this.showAllCatalog = !this.showAllCatalog;
        this.loadApplicableParts();
    }

    handleQuantityChange(event) {
        const partId = event.target.dataset.id;
        const val = parseInt(event.target.value, 10);
        this.partQuantities[partId] = (val && val > 0) ? val : 1;
    }

    async loadApplicableParts() {
        this.isLoading = true;
        try {
            if (this.showAllCatalog) {
                const globalParts = await searchParts({ searchTerm: this.searchTerm, category: '' });
                this.applicableParts = globalParts.map(p => ({
                    ...p,
                    isDirectCompatible: false
                }));
            } else {
                const data = await getApplicablePartsForWorkOrder({
                    workOrderId: this.recordId,
                    searchTerm: this.searchTerm
                });
                this.assetName = data.assetName || 'Equipment';
                this.assetModel = data.assetModel || '';
                this.assetCategory = data.assetCategory || '';
                this.applicableParts = data.parts || [];
            }
        } catch (error) {
            console.error('Error fetching applicable parts:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRaiseRequest(event) {
        const partId = event.target.dataset.id;
        const qty = this.partQuantities[partId] || 1;
        this.isLoading = true;
        try {
            await raisePartsRequestForWorkOrder({
                workOrderId: this.recordId,
                partId: partId,
                qty: qty
            });
            this.showToast('Success', `Requested ${qty}x part(s) for this Work Order.`, 'success');
            this.showRequestModal = false;
            await this.loadRequests();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to request part', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleIssuePart(event) {
        const reqId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await issuePart({ requestId: reqId });
            this.showToast('Success', 'Part issued from inventory.', 'success');
            await this.loadRequests();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to issue part', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleConsumePart(event) {
        const reqId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await consumePart({ requestId: reqId, workOrderId: this.recordId });
            this.showToast('Success', 'Part installed & recorded against Work Order.', 'success');
            await this.loadRequests();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to consume part', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleReturnPart(event) {
        const reqId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await returnPart({ requestId: reqId, reason: 'Unused part returned by field technician' });
            this.showToast('Success', 'Part returned to depot inventory.', 'success');
            await this.loadRequests();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to return part', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
