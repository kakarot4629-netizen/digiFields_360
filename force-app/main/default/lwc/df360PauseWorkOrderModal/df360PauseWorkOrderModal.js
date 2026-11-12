import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import pauseWorkOrder from '@salesforce/apex/DF360_WorkOrderPauseController.pauseWorkOrder';
import resumeWorkOrder from '@salesforce/apex/DF360_WorkOrderPauseController.resumeWorkOrder';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELDS = [
    'Work_Order__c.Status__c',
    'Work_Order__c.Current_Pause_Reason__c',
    'Work_Order__c.Current_Pause_Description__c',
    'Work_Order__c.Current_Pause_Dependency__c',
    'Work_Order__c.Paused_DateTime__c',
    'Work_Order__c.Expected_Resume_Date__c',
    'Work_Order__c.Paused_Owner_Team__c'
];

export default class Df360PauseWorkOrderModal extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track showPauseModal = false;
    @track showResumeModal = false;

    @track selectedReason = 'Waiting for Part';
    @track selectedTeam = 'Field Tech';
    @track selectedDependency = '';
    @track selectedExpectedDate = '';
    @track selectedDescription = '';
    @track resumeComments = '';

    reasonOptions = [
        { label: 'Waiting for Part', value: 'Waiting for Part' },
        { label: 'Waiting for Approval', value: 'Waiting for Approval' },
        { label: 'Waiting for Customer', value: 'Waiting for Customer' },
        { label: 'Waiting for Site Access', value: 'Waiting for Site Access' },
        { label: 'Safety Issue', value: 'Safety Issue' },
        { label: 'Vendor Dependency', value: 'Vendor Dependency' },
        { label: 'Waiting for Information', value: 'Waiting for Information' },
        { label: 'Other', value: 'Other' }
    ];

    teamOptions = [
        { label: 'Field Tech', value: 'Field Tech' },
        { label: 'Procurement', value: 'Procurement' },
        { label: 'Customer Care', value: 'Customer Care' },
        { label: 'Vendor Support', value: 'Vendor Support' },
        { label: 'Safety Officer', value: 'Safety Officer' },
        { label: 'Operations', value: 'Operations' },
        { label: 'Other', value: 'Other' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    workOrder;

    get currentStatus() {
        return getFieldValue(this.workOrder.data, 'Work_Order__c.Status__c') || 'In Progress';
    }

    get isPaused() {
        return this.currentStatus === 'Temporarily Paused';
    }

    get pauseReason() {
        return getFieldValue(this.workOrder.data, 'Work_Order__c.Current_Pause_Reason__c') || '';
    }

    get pauseDependency() {
        return getFieldValue(this.workOrder.data, 'Work_Order__c.Current_Pause_Dependency__c') || 'N/A';
    }

    get responsibleTeam() {
        return getFieldValue(this.workOrder.data, 'Work_Order__c.Paused_Owner_Team__c') || 'Field Tech';
    }

    get pausedDateTime() {
        return getFieldValue(this.workOrder.data, 'Work_Order__c.Paused_DateTime__c') || '';
    }

    get expectedResumeDate() {
        return getFieldValue(this.workOrder.data, 'Work_Order__c.Expected_Resume_Date__c') || 'Not specified';
    }

    get pauseDescription() {
        return getFieldValue(this.workOrder.data, 'Work_Order__c.Current_Pause_Description__c') || '';
    }

    openPauseModal() {
        this.showPauseModal = true;
    }

    closePauseModal() {
        this.showPauseModal = false;
    }

    openResumeModal() {
        this.showResumeModal = true;
    }

    closeResumeModal() {
        this.showResumeModal = false;
    }

    handleReasonChange(event) { this.selectedReason = event.target.value; }
    handleTeamChange(event) { this.selectedTeam = event.target.value; }
    handleDependencyChange(event) { this.selectedDependency = event.target.value; }
    handleExpectedDateChange(event) { this.selectedExpectedDate = event.target.value; }
    handleDescriptionChange(event) { this.selectedDescription = event.target.value; }
    handleResumeCommentsChange(event) { this.resumeComments = event.target.value; }

    async handleConfirmPause() {
        this.isLoading = true;
        try {
            await pauseWorkOrder({
                workOrderId: this.recordId,
                reason: this.selectedReason,
                description: this.selectedDescription,
                dependency: this.selectedDependency,
                expectedResumeDate: this.selectedExpectedDate ? new Date(this.selectedExpectedDate) : null,
                responsibleTeam: this.selectedTeam
            });
            this.showToast('Success', 'Work Order paused successfully.', 'success');
            this.showPauseModal = false;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to pause work order', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleConfirmResume() {
        if (!this.resumeComments) {
            this.showToast('Required', 'Please enter comments to resume work order.', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            await resumeWorkOrder({
                workOrderId: this.recordId,
                resumeComments: this.resumeComments
            });
            this.showToast('Success', 'Work Order resumed to In Progress.', 'success');
            this.showResumeModal = false;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to resume work order', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
