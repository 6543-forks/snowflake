# General snowflake proxy constants.
# For websocket-specific constants, see websocket.coffee.
BROKER = 'snowflake-broker.bamsoftware.com'
RELAY =
  host: 'snowflake.bamsoftware.com'
  port: '443'
  # Original non-wss relay:
  # host: '192.81.135.242'
  # port: 9902
COOKIE_NAME = "snowflake-allow"

silenceNotifications = false
query = Query.parse(location)
DEBUG = Params.getBool(query, 'debug', false)

# Bytes per second. Set to undefined to disable limit.
DEFAULT_RATE_LIMIT = DEFAULT_RATE_LIMIT || undefined
MIN_RATE_LIMIT = 10 * 1024
RATE_LIMIT_HISTORY = 5.0
DEFAULT_BROKER_POLL_INTERVAL = 5.0 * 1000

MAX_NUM_CLIENTS = 1
CONNECTIONS_PER_CLIENT = 1

# TODO: Different ICE servers.
config = {
  iceServers: [
    { urls: ['stun:stun.l.google.com:19302'] }
  ]
}

# Janky state machine
MODE =
  INIT:              0
  WEBRTC_CONNECTING: 1
  WEBRTC_READY:      2

CONFIRMATION_MESSAGE = 'You\'re currently serving a Tor user via Snowflake.'

snowflake = null

# Log to both console and UI if applicable.
# Requires that the snowflake and UI objects are hooked up in order to
# log to console.
log = (msg) ->
  console.log 'Snowflake: ' + msg
  snowflake?.ui?.log msg

dbg = (msg) -> log msg if DEBUG or snowflake.ui?.debug


###
Entry point.
###
init = (isNode) ->
  # Hook up to the debug UI if available.
  ui = if isNode then null else new UI()
  silenceNotifications = Params.getBool(query, 'silent', false)
  broker = new Broker BROKER
  snowflake = new Snowflake broker, ui

  log '== snowflake proxy =='
  if Util.snowflakeIsDisabled()
    # Do not activate the proxy if any number of conditions are true.
    log 'Currently not active.'
    return

  # Otherwise, begin setting up WebRTC and acting as a proxy.
  dbg 'Contacting Broker at ' + broker.url
  snowflake.setRelayAddr RELAY
  snowflake.beginWebRTC()

# Notification of closing tab with active proxy.
window.onbeforeunload = ->
  if !silenceNotifications && MODE.WEBRTC_READY == snowflake.state
    return CONFIRMATION_MESSAGE
  null

window.onunload = ->
  pair.close() for pair in snowflake.proxyPairs
  null

window.onload = init.bind null, false
