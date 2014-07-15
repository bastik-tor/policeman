
{
  classes:    Cc
  interfaces: Ci
  utils:      Cu
  manager:    Cm
  results:    Cr
} = Components

Cu.import 'resource://gre/modules/Services.jsm'
Cu.import 'resource://gre/modules/XPCOMUtils.jsm'

require = do ->
  reqComp = Cc["@futpib.addons.mozilla.org/policeman-internals;1"] \
                                    .getService().wrappedJSObject
  return reqComp.require

log = do ->
  { loggerFactory } = require 'log'
  return loggerFactory (window.location.href.split '/').pop()
