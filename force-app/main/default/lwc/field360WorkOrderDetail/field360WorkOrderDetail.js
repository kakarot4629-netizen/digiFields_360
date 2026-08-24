import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex actions
import generateBriefingApex      from '@salesforce/apex/F360_WorkOrderLwcController.generateBriefing';
import generateReportApex         from '@salesforce/apex/F360_WorkOrderLwcController.generateReport';
import getTroubleshootingApex     from '@salesforce/apex/F360_WorkOrderLwcController.getTroubleshootingGuidance';

// Work Order fields
import WO_NAME        from '@salesforce/schema/Work_Order__c.Name';
import WO_SUBJECT     from '@salesforce/schema/Work_Order__c.Subject__c';
import WO_STATUS      from '@salesforce/schema/Work_Order__c.Status__c';
import WO_PRIORITY    from '@salesforce/schema/Work_Order__c.Priority__c';
import WO_DESCRIPTION from '@salesforce/schema/Work_Order__c.Description__c';
import WO_ACCOUNT     from '@salesforce/schema/Work_Order__c.Account__r.Name';
import WO_SITE        from '@salesforce/schema/Work_Order__c.Site_Address__c';
import WO_SCHEDULED   from '@salesforce/schema/Work_Order__c.Scheduled_Date__c';
import WO_EQUIP_TYPE  from '@salesforce/schema/Work_Order__c.Equipment_Type__c';
import WO_EQUIP_ID    from '@salesforce/schema/Work_Order__c.Equipment_ID__c';
import WO_BRIEFING    from '@salesforce/schema/Work_Order__c.AI_Pre_Job_Briefing__c';
import WO_REPORT      from '@salesforce/schema/Work_Order__c.AI_Service_Report__c';
import WO_TECH_NOTES  from '@salesforce/schema/Work_Order__c.Technician_Notes__c';
import WO_PARTS       from '@salesforce/schema/Work_Order__c.Parts_Used__c';

const FIELDS = [
    WO_NAME, WO_SUBJECT, WO_STATUS, WO_PRIORITY, WO_DESCRIPTION,
    WO_ACCOUNT, WO_SITE, WO_SCHEDULED, WO_EQUIP_TYPE, WO_EQUIP_ID,
    WO_BRIEFING, WO_REPORT, WO_TECH_NOTES, WO_PARTS
];

export default class Field360WorkOrderDetail extends LightningElement {
    @api recordId;       // Work Order ID — passed from record page
    @api technicianLanguage = 'en';  // Set from user preference

    @track workOrder      = {};
    @track isLoading      = true;
    @track isOnline       = navigator.onLine;
    @track queueCount     = 0;

    // UI state
    @track briefingExpanded     = true;
    @track hoursWorked          = '';
    @track technicianNotes      = '';
    @track partsUsed            = '';
    @track troubleshootQuery    = '';
    @track troubleshootResult   = null;
    @track timeLogged           = false;
    @track timeLoggedMessage    = '';

    // Loading states
    @track isGeneratingBriefing = false;
    @track isGeneratingReport   = false;
    @track isTroubleshooting    = false;
    @track isLoggingTime        = false;
    @track isCompleting         = false;

    // Wire work order data
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredWorkOrder({ error, data }) {
        if (data) {
            this.workOrder = {
                Name:                  getFieldValue(data, WO_NAME) || '',
                Subject__c:            getFieldValue(data, WO_SUBJECT) || '',
                Status__c:             getFieldValue(data, WO_STATUS) || '',
                Priority__c:           getFieldValue(data, WO_PRIORITY) || '',
                Description__c:        getFieldValue(data, WO_DESCRIPTION) || '',
                Account__r:            { Name: getFieldValue(data, WO_ACCOUNT) || '' },
                Site_Address__c:       getFieldValue(data, WO_SITE) || '',
                Scheduled_Date__c:     getFieldValue(data, WO_SCHEDULED) || '',
                Equipment_Type__c:     getFieldValue(data, WO_EQUIP_TYPE) || '',
                Equipment_ID__c:       getFieldValue(data, WO_EQUIP_ID) || '',
                AI_Pre_Job_Briefing__c:getFieldValue(data, WO_BRIEFING) || '',
                AI_Service_Report__c:  getFieldValue(data, WO_REPORT) || '',
                Technician_Notes__c:   getFieldValue(data, WO_TECH_NOTES) || '',
                Parts_Used__c:         getFieldValue(data, WO_PARTS) || '',
            };
            // Pre-populate editable fields with existing values
            this.technicianNotes = this.workOrder.Technician_Notes__c || '';
            this.partsUsed       = this.workOrder.Parts_Used__c || '';
            this.isLoading = false;
        } else if (error) {
            console.error('Work order load error:', error);
            this.isLoading = false;
        }
    }

    connectedCallback() {
        window.addEventListener('online',  () => { this.isOnline = true;  });
        window.addEventListener('offline', () => { this.isOnline = false; });
    }

    disconnectedCallback() {
        window.removeEventListener('online',  () => {});
        window.removeEventListener('offline', () => {});
    }

    // ── Computed properties ─────────────────────────────────────────────────
    get accountName() {
        return this.workOrder?.Account__r?.Name || '';
    }

    get isInProgress() {
        return ['New', 'Assigned', 'In Progress'].includes(this.workOrder?.Status__c);
    }

    get isCompleted() {
        return this.workOrder?.Status__c === 'Completed';
    }

    get formattedScheduledDate() {
        if (!this.workOrder?.Scheduled_Date__c) return 'Not scheduled';
        return new Date(this.workOrder.Scheduled_Date__c).toLocaleString('en-IN', {
            dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Kolkata'
        });
    }

    get briefingPreview() {
        const b = this.workOrder?.AI_Pre_Job_Briefing__c;
        if (!b) return '';
        return b.length > 120 ? b.substring(0, 120) + '...' : b;
    }

    get statusBadgeClass() {
        const map = {
            'New': 'f360-badge f360-badge-blue',
            'Assigned': 'f360-badge f360-badge-orange',
            'In Progress': 'f360-badge f360-badge-yellow',
            'Completed': 'f360-badge f360-badge-green',
            'Cancelled': 'f360-badge f360-badge-gray',
        };
        return map[this.workOrder?.Status__c] || 'f360-badge';
    }

    get priorityBadgeClass() {
        const map = {
            'Critical': 'f360-priority f360-priority-red',
            'High':     'f360-priority f360-priority-orange',
            'Medium':   'f360-priority f360-priority-blue',
            'Low':      'f360-priority f360-priority-gray',
        };
        return map[this.workOrder?.Priority__c] || 'f360-priority';
    }

    get completeButtonLabel() {
        return this.isOnline ? 'Mark as Complete' : 'Complete (will sync when online)';
    }

    get logTimeButtonLabel() {
        return this.isOnline ? 'Log' : 'Queue';
    }

    // ── Handlers ────────────────────────────────────────────────────────────
    toggleBriefing() { this.briefingExpanded = !this.briefingExpanded; }
    handleHoursChange(e)       { this.hoursWorked      = e.detail.value; }
    handleNotesChange(e)       { this.technicianNotes  = e.detail.value; }
    handlePartsChange(e)       { this.partsUsed        = e.detail.value; }
    handleTroubleshootChange(e){ this.troubleshootQuery = e.detail.value; }

    async generateBriefing() {
        this.isGeneratingBriefing = true;
        try {
            const result = await generateBriefingApex({ workOrderId: this.recordId, languageCode: this.technicianLanguage });
            if (result?.success) {
                this.showToast('success', 'Briefing Generated', 'AI briefing is ready for this job.');
                // Refresh wire data
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } else {
                this.showToast('warning', 'Briefing Unavailable', result?.errorMessage || 'Could not generate briefing.');
            }
        } catch (e) {
            this.showToast('error', 'Error', e.body?.message || 'Failed to generate briefing.');
        } finally {
            this.isGeneratingBriefing = false;
        }
    }

    async getTroubleshootingGuidance() {
        if (!this.troubleshootQuery.trim()) return;
        this.isTroubleshooting = true;
        this.troubleshootResult = null;
        try {
            const result = await getTroubleshootingApex({ workOrderId: this.recordId, problemDescription: this.troubleshootQuery, equipmentType: this.workOrder.Equipment_Type__c, languageCode: this.technicianLanguage });
            if (result?.success) {
                this.troubleshootResult = result;
            } else {
                this.showToast('warning', 'Guidance Unavailable', result?.errorMessage || 'Could not search knowledge base.');
            }
        } catch (e) {
            this.showToast('error', 'Error', 'Knowledge base search failed. Check your connection.');
        } finally {
            this.isTroubleshooting = false;
        }
    }

    async logTime() {
        if (!this.hoursWorked || parseFloat(this.hoursWorked) <= 0) {
            this.showToast('warning', 'Enter hours', 'Please enter the number of hours worked.');
            return;
        }
        this.isLoggingTime = true;
        try {
            const minutes = Math.round(parseFloat(this.hoursWorked) * 60);
            // Update record directly
            await updateRecord({
                fields: {
                    Id: this.recordId,
                    Time_Logged_Minutes__c: minutes
                }
            });
            this.timeLogged = true;
            this.timeLoggedMessage = `${this.hoursWorked} hrs logged${!this.isOnline ? ' (queued)' : ''}`;
            this.hoursWorked = '';
        } catch (e) {
            this.showToast('error', 'Error', 'Failed to log time.');
        } finally {
            this.isLoggingTime = false;
        }
    }

    async handleCompleteJob() {
        if (!this.technicianNotes.trim()) {
            this.showToast('warning', 'Notes required', 'Please add technician notes before completing.');
            return;
        }
        this.isCompleting = true;
        try {
            // Save notes, parts, set status to Completed
            await updateRecord({
                fields: {
                    Id: this.recordId,
                    Status__c: 'Completed',
                    Technician_Notes__c: this.technicianNotes,
                    Parts_Used__c: this.partsUsed,
                    Completed_Date__c: new Date().toISOString()
                }
            });

            if (!this.isOnline) {
                this.showToast('success', 'Saved — syncing later',
                    'Job completion queued. Will sync to Salesforce when you reconnect.', 'sticky');
            } else {
                this.showToast('success', 'Job Complete', 'Work order marked as completed.');
                // Auto-generate service report
                this.generateServiceReport();
            }
        } catch (e) {
            this.showToast('error', 'Error', 'Failed to complete work order.');
        } finally {
            this.isCompleting = false;
        }
    }

    async generateServiceReport() {
        this.isGeneratingReport = true;
        try {
            const result = await generateReportApex({ workOrderId: this.recordId, sendToCustomer: false });
            if (result?.success) {
                this.showToast('success', 'Report Generated', 'Service report is ready. Tap "View Report" to review before sending to customer.');
            }
        } catch (e) {
            console.error('Report generation error:', e);
        } finally {
            this.isGeneratingReport = false;
        }
    }

    viewServiceReport() {
        // Navigate to a modal or URL with the report content
        this.dispatchEvent(new CustomEvent('viewreport', {
            detail: { report: this.workOrder.AI_Service_Report__c }
        }));
    }

    showToast(variant, title, message, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}
