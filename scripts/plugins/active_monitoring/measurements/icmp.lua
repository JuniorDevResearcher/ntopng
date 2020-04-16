--
-- (C) 2020 - ntop.org
--

--
-- This module implements the ICMP RTT probe.
--

local do_trace = false

-- #################################################################

-- This is the script state, which must be manually cleared in the check
-- function. Can be then used in the collect_results function to match the
-- probe requests with probe replies.
local pinged_hosts = {}
local resolved_hosts = {}

-- #################################################################

-- Resolve the domain name into an IP if necessary
local function resolveRttHost(domain_name, is_v6)
   local ip_address = nil

   if not isIPv4(domain_name) and not is_v6 then
     ip_address = ntop.resolveHost(domain_name, true --[[IPv4 --]])

     if not ip_address then
	if do_trace then
	   print("[RTT] Could not resolve IPv4 host: ".. domain_name .."\n")
	end
     end
   elseif not isIPv6(domain_name) and is_v6 then
      ip_address = ntop.resolveHost(domain_name, false --[[IPv6 --]])

      if not ip_address then
	if do_trace then
	   print("[RTT] Could not resolve IPv6 host: ".. domain_name .."\n")
	end
      end
   else
     ip_address = domain_name
   end

  return(ip_address)
end

-- #################################################################

-- The function called periodically to send the host probes.
-- hosts contains the list of hosts to probe, The table keys are
-- the hosts identifiers, whereas the table values contain host information
-- see (am_utils.key2host for the details on such format).
local function check_icmp(hosts, granularity)
  pinged_hosts = {}
  resolved_hosts = {}

  for key, host in pairs(hosts) do
    local domain_name = host.host
    local is_v6 = (host.measurement == "icmp6")
    local ip_address = resolveRttHost(domain_name, is_v6)

    if not ip_address then
      goto continue
    end

    if do_trace then
      print("[RTT] Pinging "..ip_address.."/"..domain_name.."\n")
    end

    -- ICMP results are retrieved in batch (see below ntop.collectPingResults)
    ntop.pingHost(ip_address, is_v6)

    pinged_hosts[ip_address] = key
    resolved_hosts[key] = ip_address

    ::continue::
  end
end

-- #################################################################

-- The function responsible for collecting the results.
-- It must return a table containing a list of hosts along with their retrieved
-- measurement. The keys of the table are the host key. The values have the following format:
--  table
--	resolved_addr: (optional) the resolved IP address of the host
--	value: the measurement numeric value
local function collect_icmp(granularity)
  local rv = {}

  -- Collect possible ICMP results
  local res = ntop.collectPingResults()

  for host, rtt in pairs(res or {}) do
    local key = pinged_hosts[host]

    if(do_trace) then
      print("[RTT] Reading ICMP response for host ".. host .."\n")
    end

    rv[key] = {
      resolved_addr = resolved_hosts[key],
      value = tonumber(rtt),
    }
  end

  return(rv)
end

-- #################################################################

return {
  -- Defines a list of measurements implemented by this script.
  -- The probing logic is implemented into the check() and collect_results().
  --
  -- Here is how the probing occurs:
  --	1. The check function is called with the list of hosts to probe. Ideally this
  --	   call should not block (e.g. should not wait for the results)
  --	2. The active_monitoring.lua code sleeps for some seconds
  --	3. The collect_results function is called. This should retrieve the results
  --       for the hosts checked in the check() function and return the results.
  --
  -- The alerts for non-responding hosts and the RTT timeseries are automatically
  -- generated by active_monitoring.lua . The timeseries are saved in the following schemas:
  -- "am_host:rtt_min", "am_host:rtt_5mins", "am_host:rtt_hour".
  measurements = {
    {
      -- The unique key for the measurement
      key = "icmp",
      -- The function called periodically to send the host probes
      check = check_icmp,
      -- The function responsible for collecting the results
      collect_results = collect_icmp,
      -- The granularities allowed for the probe. See supported_granularities in active_monitoring.lua
      granularities = {"min", "5mins", "hour"},
      -- The localization string for the measurement unit (e.g. "ms", "Mbits")
      i18n_unit = "active_monitoring_stats.msec",
      -- The localization string for the RTT timeseries menu entry
      i18n_rtt_ts_label = "graphs.num_ms_rtt",
      -- The operator to use when comparing the measurement with the threshold, "gt" for ">" or "lt" for "<".
      operator = "gt",
      -- A list of additional timeseries (the am_host:rtt_* is always shown) to show in the charts.
      -- See https://www.ntop.org/guides/ntopng/api/timeseries/adding_new_timeseries.html#charting-new-metrics .
      additional_timeseries = {},
      -- Js function to call to format the measurement value. See ntopng_utils.js .
      value_js_formatter = "fmillis",
      -- The localization string for the RTT metric in the chart
      i18n_rtt_ts_metric = "flow_details.round_trip_time",
      -- A list of additional notes (localization strings) to show into the timeseries charts
      i18n_chart_notes = {},
      -- If set, the user cannot change the host
      force_host = nil,
    }, {
      key = "icmp6",
      check = check_icmp,
      collect_results = collect_icmp,
      granularities = {"min", "5mins", "hour"},
      i18n_unit = "active_monitoring_stats.msec",
      i18n_rtt_ts_label = "graphs.num_ms_rtt",
      i18n_rtt_ts_metric = "flow_details.round_trip_time",
      operator = "gt",
      additional_timeseries = {},
      value_js_formatter = "fmillis",
      i18n_chart_notes = {},
      force_host = nil,
    },
  },

  -- A setup function to possibly disable the plugin
  setup = nil,
}
