<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <header class="mb-3 d-flex align-items-center">
  <h2 class="d-inline-block" v-html="title_html"></h2>
  </header>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card  card-shadow">
        <div class="card-body">
          <div v-if="autorefresh" class="alert alert-info alert-dismissable">
            <span class="spinner-border spinner-border-sm text-info me-1"></span> 
            <span> {{ _i18n('scan_in_progress') }}</span>
          </div>
          <div id="hosts_to_scan">
            <ModalDeleteScanConfirm ref="modal_delete_confirm" :title="title_delete" :body="body_delete" @delete="delete_row" @delete_all="delete_all_rows" @scan_row="scan_row" @scan_all_rows="scan_all_entries">
            </ModalDeleteScanConfirm>
            <ModalUpdatePeriodicityScan
              ref="modal_update_perioditicy_scan" :title="title_update_periodicity_scan" @update="update_all_scan_frequencies">
            </ModalUpdatePeriodicityScan>
            <TableWithConfig ref="table_hosts_to_scan" :table_id="table_id" :csrf="context.csrf"
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
              :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">
              <template v-slot:custom_header>
                <button class="btn btn-link" type="button" ref="add_host" @click="add_host"><i
                    class='fas fa-plus'></i></button>
              </template>
            </TableWithConfig>

          </div>
          
        </div>
        <div class="card-footer mt-3">
            <button type="button" ref="delete_all" @click="delete_all_entries" class="btn btn-danger me-1"><i
                class='fas fa-trash'></i> {{ _i18n("delete_all_entries") }}</button>

            <button type="button" ref="scan_all" @click="confirm_scan_all_entries" class="btn btn-primary me-1"><i
                class='fas fa-clock-rotate-left'></i> {{ _i18n("hosts_stats.page_scan_hosts.schedule_all_scan") }}</button>
            <template v-if="props.context.is_enterprise_l">

            <button type="button" ref="update_all" @click="update_all_periodicity" class="btn btn-secondary me-1">{{ _i18n("hosts_stats.page_scan_hosts.update_periodicity_title") }}</button>          
            </template>
            </div>

      </div>
    </div>
  </div>
  <ModalAddHostToScan ref="modal_add" :context="context" @add="add_host_rest" @edit="edit">
  </ModalAddHostToScan>
</template>
  
<script setup>

/* Imports */ 
import { ref, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";

import { default as ModalDeleteScanConfirm } from "./modal-delete-scan-confirm.vue";
import { default as ModalUpdatePeriodicityScan } from "./modal-update-periodicity-scan.vue";
import { ntopng_utility } from '../services/context/ntopng_globals_services';
import { default as ModalAddHostToScan } from "./modal-add-host-to-scan.vue";

/* ******************************************************************** */ 

/* Consts */ 
const _i18n = (t) => i18n(t);

let autorefresh = ref(false);

const title_html = ref(i18n("scan_hosts"));


const table_id = ref('hosts_to_scan');
let title_delete = _i18n('hosts_stats.page_scan_hosts.delete_host_title');
let body_delete = _i18n('hosts_stats.page_scan_hosts.delete_host_description');

let title_update_periodicity_scan = _i18n('hosts_stats.page_scan_hosts.update_periodicity_title');

const table_hosts_to_scan = ref();
const modal_delete_confirm = ref();
const modal_add = ref();
const modal_vs_result = ref();
const modal_update_perioditicy_scan = ref();

const add_host_url = `${http_prefix}/lua/rest/v2/add/host/to_scan.lua`;
const edit_host_url = `${http_prefix}/lua/rest/v2/edit/host/update_va_scan_period.lua`;
const remove_host_url = `${http_prefix}/lua/rest/v2/delete/host/delete_host_to_scan.lua`;
const scan_host_url = `${http_prefix}/lua/rest/v2/exec/host/schedule_vulnerability_scan.lua`;
const scan_type_list_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_type_list.lua`;
const active_monitoring_url = `${http_prefix}/lua/vulnerability_scan.lua`;
const scan_result_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_result.lua`;
const check_status_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_status.lua`;

const row_to_delete = ref({});
const row_to_scan = ref({});
let scan_type_list = [];

const props = defineProps({
  context: Object,
});
const rest_params = {
  csrf: props.context.csrf
};
const context = ref({
  csrf: props.context.csrf,
  ifid: props.context.ifid,
  is_enterprise_l: props.context.is_enterprise_l
});

/* ******************************************************************** */ 

/* Function to add a new host to scan */ 

function add_host() {
  if (props.context.host != null && props.context.host != "")
    modal_add.value.show(null, props.context.host);
  else
    modal_add.value.show();
  //refresh_table(true);
}

/* Function to refresh table */ 

function refresh_table(ok, disable_loading) {
  /* It's important to set autorefresh to false, in this way when refreshed 
     all the entries are going to be checked and if all of them are not scanning it stays false
   */
  if(! ok)
    autorefresh.value = false;
  else if(disable_loading == true)
    table_hosts_to_scan.value.refresh_table(disable_loading);
  else
    table_hosts_to_scan.value.refresh_table();

}

/* ******************************************************************** */ 

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ******************************************************************** */ 

/* Function to handle all buttons */
function on_table_custom_event(event) {
  
  let events_managed = {
    "click_button_edit_host": click_button_edit_host,
    "click_button_delete": click_button_delete,
    "click_button_scan": click_button_scan,
    "click_button_download": click_button_download,
    "click_button_show_result": click_button_show_result,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

function columns_sorting(col, r0, r1) {
  let r0_col = r0[col.data.data_field];
  let r1_col = r1[col.data.data_field];
  if(col.id == "host") {
    r0_col = NtopUtils.convertIPAddress(r0_col);
    r1_col = NtopUtils.convertIPAddress(r1_col);
    if (col.sort == 1) {
      return r0_col.localeCompare(r1_col);
    }
    return r1_col.localeCompare(r0_col);
  } else if(col.id == "num_vulnerabilities_found") {
    /* It's an array */
    r0_col = format_num_for_sort(r0_col);
    r1_col = format_num_for_sort(r1_col);
    if (col.sort == 1) {
      return r0_col - r1_col;
    }
    return r1_col - r0_col; 
  } else if(col.id == "num_open_ports") {
    r0_col = format_num_for_sort(r0_col);
    r1_col = format_num_for_sort(r1_col);
    if (col.sort == 1) {
      return r0_col - r1_col;
    }
    return r1_col - r0_col; 
  } else if(col.id == "duration") {
    r0_col = r0["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r0["last_scan"][col.data.data_field];
    r1_col = r1["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r1["last_scan"][col.data.data_field];
    if (col.sort == 1) {
      return r0_col.localeCompare(r1_col);
    }
    return r1_col.localeCompare(r0_col);
  } else if(col.id == "last_scan") {
    r0_col = r0["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r0["last_scan"]["time"];
    r1_col = r1["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r1["last_scan"]["time"];
    if (col.sort == 1) {
      return r0_col.localeCompare(r1_col);
    }
    return r1_col.localeCompare(r0_col);
  } else if (col.id == "is_ok_last_scan") {
    r0_col = get_scan_status_value(r0_col);
    r1_col = get_scan_status_value(r1_col);
    if (col.sort == 1) {
      return r0_col.localeCompare(r1_col);
    }
    return r1_col.localeCompare(r0_col);
  } else if(col.id == "scan_frequency") {
    r0_col = get_scan_frequency(r0_col);
    r1_col = get_scan_frequency(r1_col);
    if (col.sort == 1) {
      return r0_col.localeCompare(r1_col);
    }
    return r1_col.localeCompare(r0_col);  } else {
    if (col.sort == 1) {
      return r0_col.localeCompare(r1_col);
    }
    return r1_col.localeCompare(r0_col);
  }	
}

function get_scan_frequency(scan_frequency) {
  if (scan_frequency == "1day") {
    return i18n("hosts_stats.page_scan_hosts.daily");
  } else if (scan_frequency == "1week") {
    return i18n("hosts_stats.page_scan_hosts.weekly");
  } else {
    return "";
  }
}

function get_scan_status_value(is_ok_last_scan) {
  if (is_ok_last_scan == 4) {
    return i18n("hosts_stats.page_scan_hosts.in_progress");
  } else if (is_ok_last_scan == null) {
    return i18n("hosts_stats.page_scan_hosts.not_scanned");
  } else if (is_ok_last_scan) {
    return i18n("hosts_stats.page_scan_hosts.success");
  } else {
    return i18n("hosts_stats.page_scan_hosts.error");
  }
}

function format_num_for_sort(num) {
  if (num === "" || num === null || num === NaN || num === undefined) {
    num = 0;
  } else {
    num = num.split(',').join("")
    num = parseInt(num);
  }

  return num;
}

/* Function to handle delete button */
async function click_button_delete(event) {
  row_to_delete.value = event.row;
  modal_delete_confirm.value.show("delete_single_row",i18n("delete_vs_host"));  
}

/* Function to handle scan button */
async function click_button_scan(event) {
  row_to_scan.value = event.row;
  modal_delete_confirm.value.show("scan_row",i18n("scan_host"));  
}

/* Function to handle edit button */
function click_button_edit_host(event) {
  const row = event.row;
  //row_to_delete.value = row;
  modal_add.value.show(row);
}

/* ******************************************************************** */ 

/* Function to delete all entries */
function delete_all_entries() {
  modal_delete_confirm.value.show('delete_all', i18n('delete_all_vs_hosts'));
}

/* Function to edit host to scan */
async function edit(params) {
  //await delete_row();
  await add_host_rest(params);
}

async function check_autorefresh() {

  await check_in_progress_status();
  if(autorefresh.value == true) {
    refresh_table(true, true);
  } else {
    refresh_table(false,false)
  }
}

/* Every 10 second check if the autorefresh is enabled or not, if it is refresh the table */
setInterval(check_autorefresh, 10000);

/* ******************************************************************** */ 

/* Function to map columns data */
const map_table_def_columns = (columns) => {
  const visible_dict = {
        download: true,
        show_result: true
      };
  let map_columns = {
    "scan_type": (scan_type, row) => {
      if (scan_type !== undefined) {
        let label = scan_type
        scan_type_list.forEach((item) => {
          if (item.id.localeCompare(scan_type) == 0) {
            label = item.label;
          }
        })
        return label;
      }
    },
    "last_scan": (last_scan, row) => {
      if (last_scan !== undefined && last_scan.time !== undefined) {
        return last_scan.time;
      } else if (last_scan !== undefined) {
        return last_scan;
      } else {
        return i18n("hosts_stats.page_scan_hosts.not_yet");
      }
    },

    "duration": (last_scan, row) => {
      if (row.last_scan !== undefined && row.last_scan.duration !== undefined) {
        return row.last_scan.duration;
      } else {
        return i18n("hosts_stats.page_scan_hosts.not_yet");
      }
    },
    "scan_frequency" : (scan_frequency) => {
      let label = "";
      if (scan_frequency == null || scan_frequency == "disabled") {
        return "";
      } else if (scan_frequency == "1day") {
        label =  i18n("hosts_stats.page_scan_hosts.daily");
      } else {
        label =  i18n("hosts_stats.page_scan_hosts.weekly");
      }
      return `<span class="badge bg-secondary" title="${label}">${label}</span>`;

    }, 
    "is_ok_last_scan": (is_ok_last_scan) => {
      let label = ""
      if (is_ok_last_scan == 4) {
        //autorefresh.value = true;
        label = i18n("hosts_stats.page_scan_hosts.in_progress");
        return `<span class="badge bg-info" title="${label}">${label}</span>`;
      } else if (is_ok_last_scan == null) {
        label = i18n("hosts_stats.page_scan_hosts.not_scanned");
        return `<span class="badge bg-primary" title="${label}">${label}</span>`;
      } else if (is_ok_last_scan) {
        //autorefresh.value = autorefresh.value || false;
        label = i18n("hosts_stats.page_scan_hosts.success");
        return `<span class="badge bg-success" title="${label}">${label}</span>`;
      } else {
        //autorefresh.value = autorefresh.value || false;
        label = i18n("hosts_stats.page_scan_hosts.error");
        return `<span class="badge bg-danger" title="${label}">${label}</span>`;
      }
      
    }
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];

    if (c.id == "actions") {
            
      c.button_def_array.forEach((b) => {
          
        b.f_map_class = (current_class, row) => { 
          current_class = current_class.filter((class_item) => class_item != "link-disabled");
          if((row.is_ok_last_scan == 4 || row.is_ok_last_scan == null) && visible_dict[b.id]) {
            current_class.push("link-disabled"); 
          }
          return current_class;
        }
      });
    }
  });
  
  return columns;
};

/* ******************************************************************** */ 

onBeforeMount(async () => {
  await get_scan_type_list();
  await check_in_progress_status();
  modal_add.value.metricsLoaded(scan_type_list, context.ifid, props.context.is_enterprise_l);
})

/* ************************** REST Functions ************************** */

/* Function to add a new host during edit */
const add_host_rest = async function (params) {
  const url = NtopUtils.buildURL(add_host_url, {
    ...params
  })

  await ntopng_utility.http_post_request(url, rest_params);
  modal_add.value.close();
  refresh_table(true,false);
}

const update_all_scan_frequencies = async function(params) {
  const url = NtopUtils.buildURL(edit_host_url, {
    ...params
  })

  await ntopng_utility.http_post_request(url, rest_params);  
  refresh_table(true,false);
}

/* Function to retrieve scan types list */
const get_scan_type_list = async function () {
  const url = NtopUtils.buildURL(scan_type_list_url, {
    ...rest_params
  })

  const result = await ntopng_utility.http_request(url);
  scan_type_list = result.rsp;
}

/* Function to check if there is a scan in progress */
const check_in_progress_status = async function () {
  const url = NtopUtils.buildURL(check_status_url, {
    ...rest_params
  })

  const result = await ntopng_utility.http_request(url);
  autorefresh.value = result.rsp;
}

/* Function to confirm to start all scan */
const confirm_scan_all_entries = function() {
  modal_delete_confirm.value.show("scan_all_rows",i18n("scan_all_hosts"));  
  autorefresh.value = true;
  refresh_table(true,false);
}

/* Function to update all scan  frequencies*/
const update_all_periodicity = function() {
  modal_update_perioditicy_scan.value.show();
}

/* Function to exec the vulnerability scan of a single host */
const scan_row = async function () {
  const row = row_to_scan.value;
  const url = NtopUtils.buildURL(scan_host_url, {
    host: row.host,
    scan_type: row.scan_type,
    scan_single_host: true,
    scan_ports: row.ports,
    scan_id: row.id
  })
  await ntopng_utility.http_post_request(url, rest_params);
  autorefresh.value = true;
  refresh_table(true,false);
}

/* Function to exec a vulnerability scan to all hosts set */
async function scan_all_entries() {
  const url = NtopUtils.buildURL(scan_host_url, {
    scan_single_host: false,
  })
  await ntopng_utility.http_post_request(url, rest_params);
  autorefresh.value = false;
  refresh_table(true,false);
}

/* Function to delete host to scan */
const delete_row = async function () {
  const row = row_to_delete.value;
  const url = NtopUtils.buildURL(remove_host_url, {

    host: row.host,
    scan_type: row.scan_type,
    delete_all_scan_hosts: false,
    scan_id: row.id

  })

  await ntopng_utility.http_post_request(url, rest_params);
  refresh_table(true,false);
}


const delete_all_rows = async function() {
  const row = row_to_delete.value;
  const url = NtopUtils.buildURL(remove_host_url, {
    delete_all_scan_hosts: true
  })

  await ntopng_utility.http_post_request(url, rest_params);
  refresh_table(true,false);
}



/* Function to download last vulnerability scan result */
async function click_button_download(event) {
  let params = {
    host: event.row.host,
    scan_type: event.row.scan_type
  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${scan_result_url}?${url_params}`;
  ntopng_utility.download_URI(url);
}

/* ******************************************************************** */ 

/* Function to show last vulnerability scan result */
async function click_button_show_result(event) {
  let host = event.row.host;
  let date = event.row.last_scan.time;

  let params = {
    host: host,
    scan_type: event.row.scan_type,
    scan_return_result: true,
    page: "show_result",
    scan_date: date

  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${active_monitoring_url}?${url_params}`;
  window.open(url, "_blank");

}


/* ******************************************************************** */ 

</script>
  