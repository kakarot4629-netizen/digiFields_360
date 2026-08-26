import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent }   from 'lightning/platformShowToastEvent';
import { updateRecord }     from 'lightning/uiRecordApi';
import { refreshApex }      from '@salesforce/apex';

import getOpenWorkOrders              from '@salesforce/apex/F360_DispatchBoardController.getOpenWorkOrders';
import getActiveTechnicians           from '@salesforce/apex/F360_DispatchBoardController.getActiveTechnicians';
import getMaintenanceAlerts           from '@salesforce/apex/F360_DispatchBoardController.getMaintenanceAlerts';
import createPreventiveWorkOrder      from '@salesforce/apex/F360_DispatchBoardController.createPreventiveWorkOrder';
import getEquipment                   from '@salesforce/apex/F360_DispatchBoardController.getEquipment';
import getPartsInventory              from '@salesforce/apex/F360_DispatchBoardController.getPartsInventory';
import getJobSchedule                 from '@salesforce/apex/F360_DispatchBoardController.getJobSchedule';
import getMaintenanceRecommendations  from '@salesforce/apex/F360_DispatchBoardController.getMaintenanceRecommendations';
import getAIRecommendationApex        from '@salesforce/apex/F360_WorkOrderLwcController.recommendTechnician';

// Priority → CSS class map (used to enrich WO data objects)
const PRIORITY_CLASS = {
    'Critical': 'f360-priority-critical',
    'High':     'f360-priority-high',
    'Medium':   'f360-priority-medium',
    'Low':      'f360-priority-low',
};

// Status → CSS badge class map
const STATUS_BADGE_CLASS = {
    'New':         'f360-badge f360-badge-blue',
    'Assigned':    'f360-badge f360-badge-orange',
    'In Progress': 'f360-badge f360-badge-yellow',
    'Completed':   'f360-badge f360-badge-green',
    'Cancelled':   'f360-badge f360-badge-gray',
};

// Risk score → CSS class map
const riskClass = (score) => {
    if (score >= 80) return 'f360-risk-critical';
    if (score >= 65) return 'f360-risk-high';
    return 'f360-risk-medium';
};

/** Enrich a raw work-order record with UI helper properties */
const enrichWO = (wo, selectedTechId) => {
    const currentTechId = selectedTechId || '';
    const status = wo?.Status__c || 'New';
    return {
        ...wo,
        accountName:          wo?.Account__r?.Name || '',
        assignedTechName:     wo?.Assigned_Technician__r?.Name || '',
        priorityClass:        PRIORITY_CLASS[wo?.Priority__c] || 'f360-priority-low',
        statusBadgeClass:     STATUS_BADGE_CLASS[status] || 'f360-badge f360-badge-blue',
        selectedTechnicianId: currentTechId,
        isAssignDisabled:     !currentTechId,
        hasAIRec:             !!wo?.AI_Assignment_Reason__c,
    };
};

/** Enrich a raw maintenance-alert record with risk class */
const enrichAlert = (alert) => ({
    ...alert,
    accountName: alert?.Account__r?.Name || '',
    riskClass: riskClass(alert?.Risk_Score__c),
});

export default class Field360DispatchBoard extends LightningElement {
    @track workOrders          = [];
    @track technicians         = [];
    @track maintenanceAlerts   = [];
    @track equipment           = [];
    @track partsInventory      = [];
    @track jobSchedule         = [];
    @track recommendations     = [];
    @track isLoading           = true;
    @track isAssigning         = false;

    /** Map: workOrderId → selectedTechnicianId (for the combobox) */
    _selectedTechnicians = {};
    _wiredWorkOrders;
    _wiredAlerts;
    _wiredEquipment;
    _wiredParts;
    _wiredSchedule;
    _wiredRecommendations;

    // ── Wire calls ───────────────────────────────────────────────────────────
    @wire(getOpenWorkOrders)
    wiredWorkOrders(result) {
        this._wiredWorkOrders = result;
        if (result.data) {
            this.workOrders = result.data.map(wo =>
                enrichWO(wo, this._selectedTechnicians[wo.Id])
            );
            this.isLoading = false;
        } else if (result.error) {
            console.error('Dispatch board WO error:', result.error);
            this.isLoading = false;
        }
    }

    @wire(getActiveTechnicians)
    wiredTechnicians({ data }) {
        if (data) this.technicians = data;
    }

    @wire(getMaintenanceAlerts)
    wiredAlerts(result) {
        this._wiredAlerts = result;
        if (result.data) {
            this.maintenanceAlerts = result.data.map(enrichAlert);
        }
    }

    @wire(getEquipment)
    wiredEquipment(result) {
        this._wiredEquipment = result;
        if (result.data) {
            this.equipment = result.data;
        }
    }

    @wire(getPartsInventory)
    wiredParts(result) {
        this._wiredParts = result;
        if (result.data) {
            this.partsInventory = result.data;
        }
    }

    @wire(getJobSchedule)
    wiredSchedule(result) {
        this._wiredSchedule = result;
        if (result.data) {
            this.jobSchedule = result.data;
        }
    }

    @wire(getMaintenanceRecommendations)
    wiredRecommendations(result) {
        this._wiredRecommendations = result;
        if (result.data) {
            this.recommendations = result.data;
        }
    }

    // ── Computed properties ─────────────────────────────────────────────────
    get unassignedWorkOrders() {
        return this.workOrders.filter(wo =>
            !wo.Assigned_Technician__c && !['Completed', 'Cancelled'].includes(wo.Status__c)
        );
    }

    get assignedWorkOrders() {
        return this.workOrders.filter(wo =>
            wo.Assigned_Technician__c && !['Completed', 'Cancelled'].includes(wo.Status__c)
        );
    }

    get unassignedCount()    { return this.unassignedWorkOrders.length; }
    get assignedCount()      { return this.assignedWorkOrders.length; }
    get completedTodayCount(){ return this.workOrders.filter(wo => wo.Status__c === 'Completed').length; }
    get hasUnassigned()      { return this.unassignedCount > 0; }
    get hasAssigned()        { return this.assignedCount > 0; }
    get hasAlerts()          { return this.maintenanceAlerts.length > 0; }
    get alertCount()         { return this.maintenanceAlerts.length; }
    get hasEquipment()       { return this.equipment.length > 0; }
    get equipmentCount()     { return this.equipment.length; }
    get hasParts()           { return this.partsInventory.length > 0; }
    get partsCount()         { return this.partsInventory.length; }
    get hasSchedule()        { return this.jobSchedule.length > 0; }
    get scheduleCount()      { return this.jobSchedule.length; }
    get hasRecommendations() { return this.recommendations.length > 0; }
    get recommendationCount(){ return this.recommendations.length; }

    get technicianOptions() {
        return this.technicians.map(t => ({
            label: t.Name + (t.First_Time_Fix_Rate__c
                ? ` (${t.First_Time_Fix_Rate__c}% FTF)`
                : ''),
            value: t.Id
        }));
    }

    // ── Handlers ────────────────────────────────────────────────────────────
    async refreshBoard() {
        this.isLoading = true;
        await Promise.all([
            refreshApex(this._wiredWorkOrders),
            refreshApex(this._wiredAlerts),
            refreshApex(this._wiredEquipment),
            refreshApex(this._wiredParts),
            refreshApex(this._wiredSchedule),
            refreshApex(this._wiredRecommendations),
        ]);
        this.isLoading = false;
    }

    async getAIRecommendation(event) {
        const woId = event.target.dataset.woId;
        try {
            const result = await getAIRecommendationApex({ workOrderId: woId });
            if (result?.success && result.topTechnicianId) {
                this._selectedTechnicians[woId] = result.topTechnicianId;
                this.workOrders = this.workOrders.map(wo =>
                    wo.Id === woId ? {
                        ...wo,
                        selectedTechnicianId: result.topTechnicianId,
                        isAssignDisabled: false,
                        hasAIRec: true,
                        AI_Assignment_Reason__c: `AI recommends ${result.topTechnicianName}: ${result.topReason}`
                    } : wo
                );
                this.showToast(
                    'success',
                    'AI Recommendation',
                    `Suggested: ${result.topTechnicianName} — ${result.topReason}`
                );
                await refreshApex(this._wiredWorkOrders);
            } else {
                this.showToast('info', 'No recommendation', result?.errorMessage || 'No suitable technicians found for this work order.');
            }
        } catch (e) {
            console.error('getAIRecommendation error:', e);
            this.showToast('warning', 'Recommendation unavailable', e.body?.message || e.message || 'Could not generate AI recommendation.');
        }
    }

    handleTechnicianSelect(event) {
        const woId   = event.target.dataset.woId;
        const techId = event.detail.value;
        this._selectedTechnicians[woId] = techId;
        // Re-enrich work orders so the combobox value and Assign button stay reactive
        this.workOrders = this.workOrders.map(wo =>
            wo.Id === woId ? {
                ...wo,
                selectedTechnicianId: techId,
                isAssignDisabled: !techId
            } : wo
        );
    }

    async assignTechnician(event) {
        const woId   = event.target.dataset.woId;
        const techId = this._selectedTechnicians[woId];
        if (!techId) {
            this.showToast('warning', 'Select Technician', 'Please select a technician from the dropdown before clicking Assign.');
            return;
        }
        this.isAssigning = true;
        try {
            await updateRecord({
                fields: {
                    Id: woId,
                    Assigned_Technician__c: techId,
                    Status__c: 'Assigned'
                }
            });
            this.showToast(
                'success',
                'Technician Assigned',
                'Work order has been assigned. Status updated to Assigned.'
            );
            delete this._selectedTechnicians[woId];
            await refreshApex(this._wiredWorkOrders);
        } catch (e) {
            this.showToast('error', 'Assignment Failed', e.body?.message || 'Could not assign work order.');
        } finally {
            this.isAssigning = false;
        }
    }

    async createPreventiveWO(event) {
        const alertId = event.target.dataset.alertId;
        try {
            const wo = await createPreventiveWorkOrder({ alertId });
            this.showToast(
                'success',
                'Work Order Created',
                `Preventive maintenance WO ${wo.Name} created. Priority: ${wo.Priority__c}.`
            );
            await Promise.all([
                refreshApex(this._wiredWorkOrders),
                refreshApex(this._wiredAlerts),
                refreshApex(this._wiredRecommendations),
            ]);
        } catch (e) {
            this.showToast('error', 'Error', e.body?.message || 'Could not create work order.');
        }
    }

    showToast(variant, title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
        "warning",
        "Select Technician",
        "Please select a technician from the dropdown before clicking Assign."
      );
      return;
    }
    this.isAssigning = true;
    try {
      await updateRecord({
        fields: {
          Id: woId,
          Assigned_Technician__c: techId,
          Status__c: "Assigned"
        }
      });
      this.showToast(
        "success",
        "Technician Assigned",
        "Work order has been assigned. Status updated to Assigned."
      );
      delete this._selectedTechnicians[woId];
      await refreshApex(this._wiredWorkOrders);
    } catch (e) {
      this.showToast(
        "error",
        "Assignment Failed",
        e.body?.message || "Could not assign work order."
      );
    } finally {
      this.isAssigning = false;
    }
  }

  async createPreventiveWO(event) {
    const alertId = event.target.dataset.alertId;
    try {
      const wo = await createPreventiveWorkOrder({ alertId });
      this.showToast(
        "success",
        "Work Order Created",
        `Preventive maintenance WO ${wo.Name} created. Priority: ${wo.Priority__c}.`
      );
      await Promise.all([
        refreshApex(this._wiredWorkOrders),
        refreshApex(this._wiredAlerts),
        refreshApex(this._wiredRecommendations)
      ]);
    } catch (e) {
      this.showToast(
        "error",
        "Error",
        e.body?.message || "Could not create work order."
      );
    }
  }

  showToast(variant, title, message) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
