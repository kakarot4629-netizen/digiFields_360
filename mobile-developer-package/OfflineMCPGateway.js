/**
 * OfflineMCPGateway.js
 * Client-side Gateway Helper for digiField360 Mobile Application.
 * 
 * Drop this helper directly into your React Native / Flutter / JS Mobile app
 * to handle offline caching, mutation queuing, AI queries, and background sync.
 */

class OfflineMCPGateway {
  constructor(config = {}) {
    this.baseUrl = config.baseUrl || 'http://localhost:3000';
    this.mcpUrl = config.mcpUrl || `${this.baseUrl}/mcp`;
    this.token = config.token || '';
    this.isOnline = navigator?.onLine ?? true;
    this.offlineQueue = [];
    this.mockMode = config.mockMode ?? true;
  }

  /** Update Authentication Token */
  setToken(token) {
    this.token = token;
  }

  /** Set Mock Mode (true for local sandbox without live org) */
  setMockMode(enable) {
    this.mockMode = enable;
  }

  /** Common Request Headers */
  getHeaders() {
    const headers = {
      'Content-Type': 'application/json'
    };
    if (this.token) headers['Authorization'] = `Bearer ${this.token}`;
    if (this.mockMode) headers['x-mock-mode'] = 'true';
    return headers;
  }

  // ── 1. Shift Morning Pre-Load Sync ─────────────────────────────────────────
  async fetchMorningPayload(technicianId = 'TECH-001') {
    const res = await fetch(`${this.baseUrl}/api/sync/morning-payload?technicianId=${technicianId}`, {
      headers: this.getHeaders()
    });
    return await res.json();
  }

  // ── 1.1 Customer Accounts Query (e.g. Top 10 Accounts) ──────────────────────
  async getTopAccounts(limit = 10, industry = '') {
    const query = industry ? `?limit=${limit}&industry=${encodeURIComponent(industry)}` : `?limit=${limit}`;
    const res = await fetch(`${this.baseUrl}/api/accounts${query}`, {
      headers: this.getHeaders()
    });
    return await res.json();
  }

  // ── 2. Work Order Lifecycle ────────────────────────────────────────────────
  async getWorkOrders(statusFilter = '') {
    const query = statusFilter ? `?status=${statusFilter}` : '';
    const res = await fetch(`${this.baseUrl}/api/work-orders${query}`, {
      headers: this.getHeaders()
    });
    return await res.json();
  }

  async getWorkOrderDetails(workOrderId) {
    const res = await fetch(`${this.baseUrl}/api/work-orders/${workOrderId}`, {
      headers: this.getHeaders()
    });
    return await res.json();
  }

  async updateWorkOrderStatus(workOrderId, newStatus) {
    if (!this.isOnline) {
      return this.queueOfflineAction('status_update', workOrderId, { Status__c: newStatus });
    }
    const res = await fetch(`${this.baseUrl}/api/work-orders/${workOrderId}/status`, {
      method: 'PATCH',
      headers: this.getHeaders(),
      body: JSON.stringify({ status: newStatus })
    });
    return await res.json();
  }

  async logTimeWorked(workOrderId, hoursWorked, notes = '') {
    if (!this.isOnline) {
      return this.queueOfflineAction('time_log', workOrderId, { Time_Logged_Minutes__c: Math.round(hoursWorked * 60) });
    }
    const res = await fetch(`${this.baseUrl}/api/work-orders/${workOrderId}/time-log`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ hoursWorked, notes })
    });
    return await res.json();
  }

  async completeWorkOrder(workOrderId, completionData = {}) {
    if (!this.isOnline) {
      return this.queueOfflineAction('complete', workOrderId, completionData);
    }
    const res = await fetch(`${this.baseUrl}/api/work-orders/${workOrderId}/complete`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(completionData)
    });
    return await res.json();
  }

  // ── 3. AI Mobile Features ──────────────────────────────────────────────────
  /**
   * Dynamic Natural Language to Salesforce Query (NL2SOQL)
   * Resolves any user question to target SObject, fields, filters, and returns structured records + AI summary.
   * @param {string} prompt - e.g. "Show top 10 accounts by revenue", "Find pending work orders in Pune"
   * @param {number} maxRecords - Maximum records to retrieve (default: 10)
   */
  async askNaturalLanguageQuery(prompt, maxRecords = 10) {
    const res = await fetch(`${this.baseUrl}/api/ai/query`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ prompt, maxRecords })
    });
    return await res.json();
  }

  /**
   * Direct Dynamic SOQL Query Execution
   * @param {string} soql - Raw SOQL query string
   */
  async executeRawSOQL(soql) {
    const res = await fetch(`${this.baseUrl}/api/query/soql`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ soql })
    });
    return await res.json();
  }

  async getTroubleshootingGuidance(problemDescription, equipmentType = 'General', languageCode = 'en') {
    const res = await fetch(`${this.baseUrl}/api/ai/troubleshoot`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ problemDescription, equipmentType, languageCode })
    });
    return await res.json();
  }

  async getPreJobBriefing(workOrderId, languageCode = 'en') {
    const res = await fetch(`${this.baseUrl}/api/ai/pre-job-briefing`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ workOrderId, languageCode })
    });
    return await res.json();
  }

  // ── 4. Offline Queue & Telemetry ───────────────────────────────────────────
  queueOfflineAction(actionType, recordId, fields) {
    const queueItem = {
      queueId: `QUEUE-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      action: actionType,
      sobjectName: 'Work_Order__c',
      recordId: recordId,
      fields: fields,
      queuedAt: new Date().toISOString()
    };
    this.offlineQueue.push(queueItem);
    return {
      success: true,
      queuedOffline: true,
      queueId: queueItem.queueId,
      message: 'Action saved locally. Will sync when back online.'
    };
  }

  async syncOfflineQueue(technicianId = 'TECH-001') {
    if (this.offlineQueue.length === 0) return { success: true, message: 'Queue is empty' };

    const payload = {
      technicianId: technicianId,
      mutations: [...this.offlineQueue]
    };

    const res = await fetch(`${this.baseUrl}/api/sync/offline-queue`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(payload)
    });

    const result = await res.json();
    if (result.success) {
      this.offlineQueue = []; // Clear queue on successful sync
    }
    return result;
  }

  async sendGPSLocation(technicianId, latitude, longitude) {
    const res = await fetch(`${this.baseUrl}/api/technician/location`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ technicianId, latitude, longitude, timestamp: new Date().toISOString() })
    });
    return await res.json();
  }

  // ── 5. Standard MCP Protocol Tool Invocation ──────────────────────────────
  async callMCPTool(toolName, argumentsObj) {
    const res = await fetch(this.mcpUrl, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: Date.now(),
        method: 'tools/call',
        params: {
          name: toolName,
          arguments: argumentsObj
        }
      })
    });
    return await res.json();
  }
}

// Export for Node, ES Modules, or Browser/React Native
if (typeof module !== 'undefined' && module.exports) {
  module.exports = OfflineMCPGateway;
}
