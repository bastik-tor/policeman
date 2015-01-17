
{ path } = require 'file'
{ tabs } = require 'tabs'

{
  defineLazyProperty: deflp
} = require 'utils'


ioService = Cc["@mozilla.org/network/io-service;1"]
    .getService Ci.nsIIOService


systemPrincipal = Cc["@mozilla.org/systemprincipal;1"]
                  .createInstance Ci.nsIPrincipal
nullPrincipal = Cc["@mozilla.org/nullprincipal;1"]
                .createInstance Ci.nsIPrincipal


# maps integer values of contentType argument to strings according to
# https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIContentPolicy#Constants
intToTypeMap = [
  undefined,
  'OTHER', # 1
  'SCRIPT', # 2
  'IMAGE', # 3
  'STYLESHEET', # 4
  'OBJECT', # 5
  'DOCUMENT', # 6
  'SUBDOCUMENT', # 7
  'REFRESH', # 8
  'XBL', # 9
  'PING', # 10
  'XMLHTTPREQUEST', # 11
  'OBJECT_SUBREQUEST', # 12
  'DTD', # 13
  'FONT', # 14
  'MEDIA', # 15
  'WEBSOCKET', # 16
  'CSP_REPORT', # 17
  'XSLT', # 18
  'BEACON', # 19
]


exports.UriInfoBase = class UriInfoBase
  for property in [
    'scheme',
    'schemeType',
    'username',
    'password',
    'userPass',
    'host',
    'port',
    'hostPort',
    'prePath',
    'path',
    'pathRef',
    'spec',
    'specRef',
    'ref',
  ]
    @::[property] = ''


exports.UriInfo = class UriInfo extends UriInfoBase
  constructor: (uri) ->
    if typeof uri == 'string'
      uri = ioService.newURI uri, null, null
    @_uri = uri

  uriWithRefMap = # property of @_uri -> property of this
    'scheme'         : 'scheme'
    'username'       : 'username'
    'password'       : 'password'
    'userPass'       : 'userPass'
    'host'           : 'host'
    'port'           : 'port'
    'hostPort'       : 'hostPort'
    'prePath'        : 'prePath'
    'ref'            : 'ref'
    'path'           : 'pathRef'
    'specIgnoringRef': 'spec'
    'spec'           : 'specRef'

  for uriProp, thisProp of uriWithRefMap
    deflp @, thisProp, do (uriProp=uriProp) -> ->
      try # may throw if such component is inapplicable to uri
        value = @_uri[uriProp]
      value ?= ''
      return value

  deflp @, '_uriWithoutRef', -> @_uri?.cloneIgnoringRef()

  # can't get "path without ref" without calling uri.cloneIgnoringRef() first
  deflp @, 'path', ->
    try value = @_uriWithoutRef?.path
    value ?= ''
    return value

  schemeClassification = Object.create null # scheme -> schemeClass
  schemeClass = (cls, schemes) -> schemeClassification[s] = cls for s in schemes

  schemeClass 'internal', [
    '',
    'resource',
    'about',
    'chrome',
    'moz-icon',
    'moz-filedata',
    'view-source',
    'wyciwyg',
    'moz-nullprincipal',
  ]
  schemeClass 'inline', [
    'data',
    'blob',
    'javascript',
  ]
  schemeClass 'web', [
    'https',
    'http',
    'ftp',
    'wss',
    'ws',
  ]
  schemeClass 'file', [
    'file',
  ]

  classifyScheme = (s) -> schemeClassification[s] or 'unknown'

  deflp @, 'schemeType', -> classifyScheme @scheme


exports.OriginInfo = class OriginInfo extends UriInfo

exports.DestinationInfo = class DestinationInfo extends UriInfo


exports.ContextInfoBase = class ContextInfoBase
  for property in [
    'nodeName',
    'className',
    'classList',
    'id',
    'contentType',
    'mime',
    'specialPrincipal',
    'hook',
  ]
    @::[property] = ''


exports.ContextInfo = class ContextInfo extends ContextInfoBase
  components: Object.keys ContextInfoBase::

  constructor: (originUri, destUri, context, contentType, mime, principal) ->
    @contentType = intToTypeMap[contentType] or ''
    @mime = mime or ''

    @_context = context
    @_principal = principal

    @hook = 'shouldLoad'

  for prop, iface of {
    '_node'    : Ci.nsIDOMNode
    '_element' : Ci.nsIDOMElement
    '_document': Ci.nsIDOMDocument
    '_window'  : Ci.nsIDOMWindow
  }
    deflp @, prop, do (iface=iface) -> ->
      if @_context instanceof iface then @_context

  deflp @, 'nodeName', ->
    if @_window
      return '#window'
    else if @_node
      return @_node.nodeName.toLowerCase()
    else
      return ''

  deflp @, 'id', ->
    if (bv = @_element?.id?.baseVal)? # SVGAnimatedString
      return bv
    return @_element?.id or ''

  deflp @, 'className', ->
    if (bv = @_element?.className?.baseVal)?
      return bv
    return @_element?.className or ''

  deflp @, 'classList', ->
    l = Object.create null
    for c in @className.split(' ')
      l[c] = true
    return l

  XUL_NAMESPACE = 'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul'
  getWindowFromRequestContext = (ctx) ->
    # gets dom window from context argument content policy's shouldLoad gets
    # https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIContentPolicy#shouldLoad%28%29
    # reference says it's either nsIDOMNode or nsIDOMWindow
    if ctx instanceof Ci.nsIDOMWindow
      return ctx
    if ctx instanceof Ci.nsIDOMDocument
      return ctx.defaultView
    if ctx instanceof Ci.nsIDOMNode
      if (ctx.localName == 'browser') and (ctx.namespaceURI == XUL_NAMESPACE)
        return ctx.contentWindow
      # this will be chrome window in some cases
      return ctx.ownerDocument.defaultView

  deflp @, '_tabId', ->
    tab = tabs.getWindowOwner getWindowFromRequestContext @_context
    if tab
      return tabs.getTabId tab
    return ''

  deflp @, 'specialPrincipal', ->
    if @_principal
      if (try systemPrincipal.equals @_principal)
        return 'system'
      else if (try nullPrincipal.equals @_principal)
        return 'null'
    return ''


exports.ChannelInfo = class ChannelInfo
  constructor: (channel) ->
    @_channel = channel

  deflp @, '_triggeringPrincipal', -> @_channel?.loadInfo?.triggeringPrincipal
  deflp @, '_loadingPrincipal', -> @_channel?.loadInfo?.loadingPrincipal

  for prop, iface of {
    '_loadContext' : Ci.nsILoadContext
    '_webProgress' : Ci.nsIWebProgress
    '_webNav'      : Ci.nsIWebNavigation
    '_docShell'    : Ci.nsIDocShell

    '_node'        : Ci.nsIDOMNode
    '_element'     : Ci.nsIDOMElement
    '_document'    : Ci.nsIDOMDocument
    '_window'      : Ci.nsIDOMWindow

    '_xhr'         : Ci.nsIXMLHttpRequest
  }
    deflp @, prop, do (iface=iface) -> ->
      try
        return @_channel.notificationCallbacks.getInterface iface

  deflp @, '_documentIndirect', -> # getting document by more unobvious means
    return @_document \
        or @_channel.loadInfo?.loadingDocument \
        or @_webNav?.document \
        or @_node?.ownerDocument

  deflp @, '_windowIndirect', ->
    return @_window \
        or (try @_loadContext.associatedWindow) \
        or @_documentIndirect?.defaultView \
        or @_webProgress?.DOMWindow

  deflp @, '_originLocationUri', ->
    if (uri = @_webNav?.currentURI)?
      return uri
    if (uri = @_documentIndirect?.documentUTIObject)?
      return uri
    if @_windowIndirect then try
      return ioService.newURI @_windowIndirect.location.href, null, null
    return undefined

  deflp @, '_originPrincipalUri', ->
    return @_triggeringPrincipal?.URI \
        or @_triggeringPrincipal?.originalURI \
        or @_loadingPrincipal?.URI \
        or @_loadingPrincipal?.originalURI

  deflp @, 'originUri', ->
    return @_originPrincipalUri \
        or @_originLocationUri

  deflp @, 'destUri', -> @_channel.URI

  deflp @, 'context', ->
    return @_element \
        or @_document \
        or @_node \
        or @_window \
        or @_documentIndirect \
        or @_windowIndirect

  deflp @, 'contentType', ->
    if @_channel.loadInfo?.contentPolicyType?
      return @_channel.loadInfo.contentPolicyType
    if @_xhr
      return Ci.nsIContentPolicy.TYPE_XMLHTTPREQUEST
    return undefined

  deflp @, 'mime', -> try @_channel.contentType

  deflp @, 'principal', -> @_triggeringPrincipal or @_loadingPrincipal


exports.ChannelOriginInfo = class ChannelOriginInfo extends OriginInfo
  constructor: (channelInfo) ->
    super channelInfo.originUri

exports.ChannelDestinationInfo = class ChannelDestinationInfo extends DestinationInfo
  constructor: (channelInfo) ->
    super channelInfo.destUri


exports.ChannelContextInfo = class ChannelContextInfo extends ContextInfo
  constructor: (channelInfo) ->
    super channelInfo.originUri,
          channelInfo.destUri,
          channelInfo.context,
          channelInfo.contentType,
          channelInfo.mime,
          channelInfo.principal

    @hook = 'modifyRequest'


infoMangling = new class
  ###
  This object holds hooks that are called by get*InfoObjects functions below
  for them to change info objects in some special cases (like making favicon
  requests look like thay are made by content documents, not by chrome).
  ###

  class ManglingHook
    class Hooks
      constructor: -> @_hooks = []
      add: (f) -> @_hooks.push f
      invoke: ->
        for h in @_hooks
          try
            if v = h arguments...
              return v
          catch e
            log.error 'Mangling hook', h, 'threw', e
        return undefined

    raw: new Hooks
    wrapped: new Hooks

  shouldLoad = new ManglingHook
  channel = new ManglingHook

  shouldLoad: shouldLoad
  channel: channel

  # Favicon requests handling

  favicons = new class # keeps all the favicon URLs and corresponding tabs
    faviconUrlToTab = Object.create null

    iconChangeObserver = null

    onOpen = (t) ->
      if not iconChangeObserver
        { MutationObserver } = t.ownerDocument.defaultView
        iconChangeObserver = new MutationObserver (mutations) ->
          for m in mutations
            if old = m.oldValue
              delete faviconUrlToTab[old]
            if new_ = m.target.image
              faviconUrlToTab[new_] = m.target
      iconChangeObserver.observe t,
        attributes: yes
        attributeOldValue: yes
        attributeFilter: ['image']
      faviconUrlToTab[t.image] = t

    onClose = (t) ->
      delete faviconUrlToTab[t.image]

    onOpen t for t in tabs.list
    tabs.onOpen.add onOpen
    tabs.onClose.add onClose

    isIconUrl: (url) -> url of faviconUrlToTab
    getTabForIcon: (url) -> faviconUrlToTab[url]

  channel.wrapped.add (origin, dest, ctx, channelInfo) ->
    ###
    Detects favicon requests and makes them look like they were made by
    corresponding content documents, not by chrome which they actually are.
    ###
    if  ctx.specialPrincipal == 'system' \
    and origin.spec == 'chrome://browser/content/browser.xul' \
    and (favicons.isIconUrl dest.specRef)
      tab = favicons.getTabForIcon dest.specRef

      browser = tab.linkedBrowser
      window = browser.contentWindow
      document = browser.contentDocument

      newDest = dest
      newOrigin = new OriginInfo window.location.href
      newCtx = new ContextInfo \
              newOrigin,
              newDest,
              document,
              Ci.nsIContentPolicy.TYPE_IMAGE,
              null,
              ctx._principal

      return [newOrigin, newDest, newCtx]
    return undefined


exports.getShouldLoadInfoObjects = \
  (contentType, destUri, originUri, context, mime, extra, principal) ->
    if mangled = infoMangling.shouldLoad.raw.invoke arguments...
      return mangled

    origin = new OriginInfo originUri
    dest = new DestinationInfo destUri
    ctx = new ContextInfo originUri, destUri, context, contentType, mime, principal

    if mangled = infoMangling.shouldLoad.wrapped.invoke origin, dest, ctx
      return mangled

    return [origin, dest, ctx]

exports.getChannelInfoObjects = (channel) ->
  if mangled = infoMangling.channel.raw.invoke arguments...
    return mangled

  channelInfo = new ChannelInfo channel
  origin = new ChannelOriginInfo channelInfo
  dest = new ChannelDestinationInfo channelInfo
  ctx = new ChannelContextInfo channelInfo

  if mangled = infoMangling.channel.wrapped.invoke origin, dest, ctx, channelInfo
    return mangled

  return [origin, dest, ctx, channelInfo]
