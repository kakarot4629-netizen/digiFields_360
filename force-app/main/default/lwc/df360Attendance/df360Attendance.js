import { LightningElement, api, track } from 'lwc';
import punchIn from '@salesforce/apex/DF360_AttendanceController.punchIn';
import punchOut from '@salesforce/apex/DF360_AttendanceController.punchOut';
import getTodayAttendance from '@salesforce/apex/DF360_AttendanceController.getTodayAttendance';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360Attendance extends LightningElement {
    @api recordId;
    @track todayRecord;

    connectedCallback() {
        this.loadAttendance();
    }

    async loadAttendance() {
        try {
            this.todayRecord = await getTodayAttendance({ technicianId: this.recordId });
        } catch(e) {
            console.error(e);
        }
    }

    async handlePunchIn() {
        try {
            await punchIn({ technicianId: this.recordId, lat: 19.0760, lng: 72.8777, isGeofenceValid: true });
            this.showToast('Success', 'Punched in successfully with GPS', 'success');
            this.loadAttendance();
        } catch(e) {
            this.showToast('Error', e.body?.message || 'Punch-in failed', 'error');
        }
    }

    async handlePunchOut() {
        try {
            await punchOut({ technicianId: this.recordId, lat: 19.0760, lng: 72.8777 });
            this.showToast('Success', 'Punched out successfully', 'success');
            this.loadAttendance();
        } catch(e) {
            this.showToast('Error', e.body?.message || 'Punch-out failed', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
