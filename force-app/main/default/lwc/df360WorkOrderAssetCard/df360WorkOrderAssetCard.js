import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAsset360Details from '@salesforce/apex/DF360_WorkOrderAssetController.getAsset360Details';
import associateAsset from '@salesforce/apex/DF360_WorkOrderAssetController.associateAsset';
import searchAssets from '@salesforce/apex/DF360_WorkOrderAssetController.searchAssets';
import getWorkOrderLineItems from '@salesforce/apex/DF360_WorkOrderAssetController.getWorkOrderLineItems';
import addLineItem from '@salesforce/apex/DF360_WorkOrderAssetController.addLineItem';
import saveAssetAssessment from '@salesforce/apex/DF360_WorkOrderAssetController.saveAssetAssessment';
import saveAssetPhotos from '@salesforce/apex/DF360_WorkOrderAssetController.saveAssetPhotos';
import linkPhotoDocument from '@salesforce/apex/DF360_WorkOrderAssetController.linkPhotoDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360WorkOrderAssetCard extends NavigationMixin(LightningElement) {
    @api recordId; // Work_Order__c Id
    @track isLoading = false;
    @track asset = null;
    @track lineItems = [];
    @track pastWorkOrders = [];
    @track jobHistories = [];
    @track documents = [];
    @track searchResults = [];

    // Modal Visibility
    @track showSearchModal = false;
    @track isAddingLineItem = false;
    @track showHistoryModal = false;
    @track showDocsModal = false;
    @track showAssessmentModal = false;
    @track showPhotosModal = false;

    // Active Line Item for Modals
    @track selectedLineItem = null;
    @track modalOperationalStatus = '';
    @track modalTechnicianFeedback = '';
    @track modalAssetCondition = '';
    @track modalPrePhotoUrl = '';
    @track modalPostPhotoUrl = '';

    operationalStatusOptions = [
        { label: 'Working / Operational', value: 'Working / Operational' },
        { label: 'Not Working / Defective', value: 'Not Working / Defective' },
        { label: 'Partially Working / Sub-optimal', value: 'Partially Working / Sub-optimal' },
        { label: 'Pending Inspection', value: 'Pending Inspection' },
        { label: 'Replaced / Repaired', value: 'Replaced / Repaired' }
    ];

    conditionOptions = [
        { label: 'Excellent', value: 'Excellent' },
        { label: 'Good', value: 'Good' },
        { label: 'Fair', value: 'Fair' },
        { label: 'Poor', value: 'Poor' },
        { label: 'Critical Damage', value: 'Critical Damage' }
    ];

    connectedCallback() {
        this.loadAssetDetails();
    }

    get hasAsset() {
        return this.asset != null;
    }

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get hasJobHistories() {
        return this.jobHistories && this.jobHistories.length > 0;
    }

    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }

    get acceptedPhotoFormats() {
        return ['.png', '.jpg', '.jpeg', '.webp'];
    }

    get formattedDocuments() {
        return this.documents.map(doc => {
            let iconName = 'doctype:unknown';
            const ext = (doc.extension || '').toLowerCase();
            if (['pdf'].includes(ext)) iconName = 'doctype:pdf';
            else if (['jpg', 'jpeg', 'png', 'webp'].includes(ext)) iconName = 'doctype:image';
            else if (['doc', 'docx'].includes(ext)) iconName = 'doctype:word';
            else if (['xls', 'xlsx'].includes(ext)) iconName = 'doctype:excel';

            const sizeKb = doc.size ? Math.round(doc.size / 1024) + ' KB' : '';
            return {
                ...doc,
                iconName,
                sizeKb,
                viewUrl: `/lightning/r/ContentDocument/${doc.id}/view`
            };
        });
    }

    get primaryAssetUrl() {
        return this.asset && this.asset.Id ? `/lightning/r/Asset__c/${this.asset.Id}/view` : '#';
    }

    get searchModalTitle() {
        return this.isAddingLineItem ? 'Add Equipment to Case Assets' : 'Associate Primary Asset with Work Order';
    }

    get formattedLineItems() {
        if (!this.lineItems) return [];
        const todayStr = new Date().toISOString().split('T')[0];

        return this.lineItems.map(item => {
            const assetObj = item.Asset__r || {};
            const isWarrantyActive = assetObj.Is_Under_Warranty__c === true ||
                (assetObj.Warranty_Expiry__c && assetObj.Warranty_Expiry__c >= todayStr);

            let opBadgeClass = 'slds-badge';
            const opStatus = item.Operational_Status__c || 'Pending Inspection';
            if (opStatus.includes('Working / Operational')) {
                opBadgeClass = 'slds-badge slds-theme_success';
            } else if (opStatus.includes('Not Working / Defective')) {
                opBadgeClass = 'slds-badge slds-theme_error';
            } else if (opStatus.includes('Partially Working')) {
                opBadgeClass = 'slds-badge slds-theme_warning';
            } else if (opStatus.includes('Replaced / Repaired')) {
                opBadgeClass = 'slds-badge slds-theme_alt-inverse';
            }

            let photoCount = 0;
            if (item.Pre_Service_Photo_URL__c) photoCount++;
            if (item.Post_Service_Photo_URL__c) photoCount++;

            return {
                ...item,
                assetUrl: item.Asset__c ? `/lightning/r/Asset__c/${item.Asset__c}/view` : '#',
                lineItemUrl: item.Id ? `/lightning/r/Work_Order_Line_Item__c/${item.Id}/view` : '#',
                isWarrantyActive: isWarrantyActive,
                warrantyBadgeClass: isWarrantyActive ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_error',
                warrantyLabel: isWarrantyActive ? 'Active Warranty' : 'Expired / None',
                operationalStatusClass: opBadgeClass,
                operationalStatusDisplay: item.Operational_Status__c || 'Pending',
                feedbackDisplay: item.Technician_Feedback__c || 'No feedback recorded yet.',
                hasFeedback: Boolean(item.Technician_Feedback__c),
                conditionDisplay: item.Asset_Condition__c || 'Good',
                hasPhotos: photoCount > 0,
                photoCountLabel: photoCount > 0 ? `${photoCount} Photo(s)` : 'No Photos',
                photoBadgeClass: photoCount === 2 ? 'slds-badge slds-theme_success' : (photoCount === 1 ? 'slds-badge slds-theme_warning' : 'slds-badge')
            };
        });
    }

    get formattedPastWorkOrders() {
        if (!this.pastWorkOrders) return [];
        return this.pastWorkOrders.map(wo => ({
            ...wo,
            workOrderUrl: wo.Id ? `/lightning/r/Work_Order__c/${wo.Id}/view` : '#'
        }));
    }

    async loadAssetDetails() {
        this.isLoading = true;
        try {
            const [data, items] = await Promise.all([
                getAsset360Details({ assetId: null, workOrderId: this.recordId }),
                getWorkOrderLineItems({ workOrderId: this.recordId })
            ]);
            if (data && data.success) {
                this.asset = data.asset;
                this.pastWorkOrders = data.pastWorkOrders || [];
                this.jobHistories = data.jobHistories || [];
                this.documents = data.documents || [];
            } else {
                this.asset = null;
                this.pastWorkOrders = [];
                this.jobHistories = [];
                this.documents = [];
            }
            this.lineItems = items || [];
        } catch (error) {
            console.error('Error loading asset details:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Search / Add Line Item Modals
    openSearchModal() {
        this.isAddingLineItem = false;
        this.showSearchModal = true;
        this.handleSearch('');
    }

    openAddLineItemModal() {
        this.isAddingLineItem = true;
        this.showSearchModal = true;
        this.handleSearch('');
    }

    closeSearchModal() {
        this.showSearchModal = false;
        this.isAddingLineItem = false;
    }

    openHistoryModal() {
        this.showHistoryModal = true;
    }

    closeHistoryModal() {
        this.showHistoryModal = false;
    }

    openDocsModal() {
        this.showDocsModal = true;
    }

    closeDocsModal() {
        this.showDocsModal = false;
    }

    handleSearchInput(event) {
        this.handleSearch(event.target.value);
    }

    async handleSearch(searchTerm) {
        try {
            this.searchResults = await searchAssets({ searchTerm: searchTerm, accountId: null });
        } catch (error) {
            console.error('Error searching assets:', error);
        }
    }

    async handleSelectAsset(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            if (this.isAddingLineItem) {
                const seq = (this.lineItems ? this.lineItems.length : 0) + 1;
                await addLineItem({
                    workOrderId: this.recordId,
                    assetId: selectedId,
                    description: 'Scheduled service & inspection for Case Asset',
                    sequence: seq
                });
                this.showToast('Success', 'Asset added to Case Assets.', 'success');
            } else {
                const result = await associateAsset({ workOrderId: this.recordId, assetId: selectedId });
                this.asset = result.asset;
                this.pastWorkOrders = result.pastWorkOrders || [];
                this.jobHistories = result.jobHistories || [];
                this.documents = result.documents || [];
                this.showToast('Success', 'Primary Asset associated with Work Order successfully.', 'success');
            }
            this.closeSearchModal();
            await this.loadAssetDetails();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to link asset', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ==========================================
    // ASSESSMENT & FEEDBACK MODAL
    // ==========================================
    openAssessmentModal(event) {
        const lineItemId = event.currentTarget.dataset.id;
        const item = this.lineItems.find(i => i.Id === lineItemId);
        if (item) {
            this.selectedLineItem = item;
            this.modalOperationalStatus = item.Operational_Status__c || 'Pending Inspection';
            this.modalTechnicianFeedback = item.Technician_Feedback__c || '';
            this.modalAssetCondition = item.Asset_Condition__c || 'Good';
            this.showAssessmentModal = true;
        }
    }

    closeAssessmentModal() {
        this.showAssessmentModal = false;
        this.selectedLineItem = null;
    }

    handleOperationalStatusChange(event) {
        this.modalOperationalStatus = event.detail.value;
    }

    handleAssetConditionChange(event) {
        this.modalAssetCondition = event.detail.value;
    }

    handleFeedbackChange(event) {
        this.modalTechnicianFeedback = event.detail.value;
    }

    async handleSaveAssessment() {
        if (!this.selectedLineItem) return;
        this.isLoading = true;
        try {
            await saveAssetAssessment({
                lineItemId: this.selectedLineItem.Id,
                operationalStatus: this.modalOperationalStatus,
                feedback: this.modalTechnicianFeedback,
                condition: this.modalAssetCondition
            });
            this.showToast('Assessment Saved', 'Technician feedback and operational status updated.', 'success');
            this.closeAssessmentModal();
            await this.loadAssetDetails();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to save assessment', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ==========================================
    // PRE & POST SERVICE PHOTOS MODAL
    // ==========================================
    openPhotosModal(event) {
        const lineItemId = event.currentTarget.dataset.id;
        const item = this.lineItems.find(i => i.Id === lineItemId);
        if (item) {
            this.selectedLineItem = item;
            this.modalPrePhotoUrl = item.Pre_Service_Photo_URL__c || '';
            this.modalPostPhotoUrl = item.Post_Service_Photo_URL__c || '';
            this.showPhotosModal = true;
        }
    }

    closePhotosModal() {
        this.showPhotosModal = false;
        this.selectedLineItem = null;
    }

    handlePrePhotoUrlChange(event) {
        this.modalPrePhotoUrl = event.target.value;
    }

    handlePostPhotoUrlChange(event) {
        this.modalPostPhotoUrl = event.target.value;
    }

    async handlePhotoUploadFinished(event) {
        const photoType = event.currentTarget.dataset.type; // 'PRE' or 'POST'
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) return;

        const documentId = uploadedFiles[0].documentId;
        this.isLoading = true;
        try {
            const res = await linkPhotoDocument({
                lineItemId: this.selectedLineItem.Id,
                contentDocumentId: documentId,
                photoType: photoType
            });

            if (photoType === 'PRE') {
                this.modalPrePhotoUrl = res.url;
            } else {
                this.modalPostPhotoUrl = res.url;
            }

            this.showToast('Photo Uploaded', `${photoType === 'PRE' ? 'Pre-Service' : 'Post-Service'} photo linked successfully.`, 'success');
            await this.loadAssetDetails();

            // Refresh selectedLineItem reference
            this.selectedLineItem = this.lineItems.find(i => i.Id === this.selectedLineItem.Id) || this.selectedLineItem;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to link uploaded photo', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSavePhotos() {
        if (!this.selectedLineItem) return;
        this.isLoading = true;
        try {
            await saveAssetPhotos({
                lineItemId: this.selectedLineItem.Id,
                prePhotoUrl: this.modalPrePhotoUrl,
                postPhotoUrl: this.modalPostPhotoUrl
            });
            this.showToast('Photos Updated', 'Pre & Post Service Photo URLs saved.', 'success');
            this.closePhotosModal();
            await this.loadAssetDetails();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to save photos', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ==========================================
    // UTILITIES
    // ==========================================
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleNavigateToRecord(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        const objectApiName = event.currentTarget.dataset.object;
        if (!recordId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'view'
            }
        });
    }
}
