/**
 * MCP Avadi CRM – Google Apps Script Backend
 *
 * ACTUAL sheet columns (A–I, NO ID column):
 * A: Customer Name | B: Phone Number | C: Place | D: Lead Given by |
 * E: Site Visited | F: Date | G: Notes | H: Booking Status | I: Registration Status
 *
 * DEPLOY: Execute as = Me, Who has access = Anyone
 * After code change → Deploy → New deployment → copy URL → update constants.dart
 */

var SHEET_NAME = 'Sheet1';

function getSheet() {
  return SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
}

function str(v) {
  if (v === null || v === undefined) return '';
  return v.toString().trim();
}

function jsonResp(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

function parseBody(e) {
  try {
    if (e.postData && e.postData.contents) {
      return JSON.parse(e.postData.contents);
    }
  } catch (err) {}
  return e.parameter || {};
}

// ── GET: Fetch all customers ──────────────────────────────────────────────────
function doGet(e) {
  try {
    var sheet = getSheet();
    var lastRow = sheet.getLastRow();
    if (lastRow < 2) {
      return jsonResp({ status: 'success', data: [] });
    }

    var lastCol = sheet.getLastColumn();
    var data = sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();
    var customers = [];

    for (var i = 0; i < data.length; i++) {
      var row = data[i];
      var name  = str(row[0]);
      var phone = str(row[1]);
      if (!name && !phone) continue;

      customers.push({
        'Customer Name':       name,
        'Phone Number':        phone,
        'Place':               str(row[2]),
        'Lead Given by':       str(row[3]),
        'Site Visited':        str(row[4]),
        'Date':                str(row[5]),
        'Notes':               str(row[6]),
        'Booking Status':      str(row[7]) || 'Pending',
        'Registration Status': str(row[8]) || 'Pending'
      });
    }

    return jsonResp({ status: 'success', data: customers });
  } catch (err) {
    return jsonResp({ status: 'error', message: err.toString() });
  }
}

// ── POST: Create / Update / Delete ────────────────────────────────────────────
function doPost(e) {
  try {
    var body = parseBody(e);
    var action = str(body.action).toLowerCase();

    Logger.log('ACTION: ' + action);
    Logger.log('BODY: ' + JSON.stringify(body));

    if (action === 'create') return handleCreate(body);
    if (action === 'update') return handleUpdate(body);
    if (action === 'delete') return handleDelete(body);

    return jsonResp({ status: 'error', message: 'Unknown action: ' + action });
  } catch (err) {
    Logger.log('doPost ERROR: ' + err.toString());
    return jsonResp({ status: 'error', message: err.toString() });
  }
}

// ── CREATE ────────────────────────────────────────────────────────────────────
function handleCreate(body) {
  var sheet = getSheet();

  sheet.appendRow([
    str(body['Customer Name']),
    str(body['Phone Number']),
    str(body['Place']),
    str(body['Lead Given by']),
    str(body['Site Visited']),
    str(body['Date']),
    str(body['Notes']),
    str(body['Booking Status'])  || 'Pending',
    str(body['Registration Status']) || 'Pending'
  ]);

  Logger.log('CREATED: ' + str(body['Customer Name']));
  return jsonResp({ status: 'success', action: 'create' });
}

// ── FIND ROW by matching fields ───────────────────────────────────────────────
// Uses: Customer Name + Phone Number + Place + Lead Given by + Date
function findRow(sheet, name, phone, place, lead, date) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return -1;

  var lastCol = sheet.getLastColumn();
  var data = sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();

  var mName  = str(name).toLowerCase();
  var mPhone = str(phone).toLowerCase();
  var mPlace = str(place).toLowerCase();
  var mLead  = str(lead).toLowerCase();
  var mDate  = str(date).toLowerCase();

  for (var i = 0; i < data.length; i++) {
    var rName  = str(data[i][0]).toLowerCase();
    var rPhone = str(data[i][1]).toLowerCase();
    var rPlace = str(data[i][2]).toLowerCase();
    var rLead  = str(data[i][3]).toLowerCase();
    var rDate  = str(data[i][5]).toLowerCase();

    if (rName === mName && rPhone === mPhone && rPlace === mPlace &&
        rLead === mLead && rDate === mDate) {
      return i + 2; // 1-based, skip header
    }
  }

  // Fallback: match by name + phone only
  for (var j = 0; j < data.length; j++) {
    var rn = str(data[j][0]).toLowerCase();
    var rp = str(data[j][1]).toLowerCase();
    if (rn === mName && rp === mPhone) {
      return j + 2;
    }
  }

  return -1;
}

// ── UPDATE ────────────────────────────────────────────────────────────────────
function handleUpdate(body) {
  var sheet = getSheet();

  // Find the ORIGINAL row using original values (pre-edit)
  var origName  = str(body['originalCustomerName'] || body['Customer Name']);
  var origPhone = str(body['originalPhoneNumber']  || body['Phone Number']);
  var origPlace = str(body['originalPlace']         || body['Place']);
  var origLead  = str(body['originalLeadGivenBy']   || body['Lead Given by']);
  var origDate  = str(body['originalDate']           || body['Date']);

  var rowIndex = findRow(sheet, origName, origPhone, origPlace, origLead, origDate);

  if (rowIndex === -1) {
    Logger.log('UPDATE FAILED: row not found for ' + origName + ' / ' + origPhone);
    return jsonResp({ status: 'error', message: 'Customer not found for update.' });
  }

  // Overwrite the existing row with NEW values — NEVER append
  var lastCol = sheet.getLastColumn();
  var numCols = Math.max(lastCol, 9);
  sheet.getRange(rowIndex, 1, 1, numCols).setValues([[
    str(body['Customer Name']),
    str(body['Phone Number']),
    str(body['Place']),
    str(body['Lead Given by']),
    str(body['Site Visited']),
    str(body['Date']),
    str(body['Notes']),
    str(body['Booking Status'])  || 'Pending',
    str(body['Registration Status']) || 'Pending'
  ]]);

  Logger.log('UPDATED row ' + rowIndex + ': ' + str(body['Customer Name']));
  return jsonResp({ status: 'success', action: 'update', row: rowIndex });
}

// ── DELETE ────────────────────────────────────────────────────────────────────
function handleDelete(body) {
  var sheet = getSheet();

  var name  = str(body['Customer Name']);
  var phone = str(body['Phone Number']);
  var place = str(body['Place']);
  var lead  = str(body['Lead Given by']);
  var date  = str(body['Date']);

  var rowIndex = findRow(sheet, name, phone, place, lead, date);

  if (rowIndex === -1) {
    Logger.log('DELETE FAILED: row not found for ' + name + ' / ' + phone);
    return jsonResp({ status: 'error', message: 'Customer not found for delete.' });
  }

  // Delete the ENTIRE row — shifts rows up, no blanks
  sheet.deleteRow(rowIndex);

  Logger.log('DELETED row ' + rowIndex + ': ' + name);
  return jsonResp({ status: 'success', action: 'delete', row: rowIndex });
}
