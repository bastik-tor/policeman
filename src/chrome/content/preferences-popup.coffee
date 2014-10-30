

{ manager } = require 'ruleset/manager'
{ popup } = require 'ui/popup'

{ DomainDomainTypeRS } = require 'ruleset/code-ruleset'

{ l10n } = require 'l10n'


window.top.location.hash = "#popup"


USER_AVAILABLE_CONTENT_TYPES = DomainDomainTypeRS::USER_AVAILABLE_CONTENT_TYPES

checkbox = (selector, initialState, oncommand) ->
  cb = $ selector
  cb.checked = initialState
  cb.addEventListener 'command', oncommand

onLoad = ->
  checkbox '#autoreload-popup', popup.autoreload.enabled(), ->
    if @checked
      popup.autoreload.enable()
    else
      popup.autoreload.disable()

  groupbox = $ '#content-type-groupbox'
  for type in USER_AVAILABLE_CONTENT_TYPES
    id = "content-type-checkbox-#{type}"
    groupbox.appendChild cb = createElement 'checkbox',
      id: id
      label: l10n "content_type.title.plural.#{type}"
    if type == DomainDomainTypeRS::WILDCARD_TYPE
      cb.disabled = true

    checkbox "##{id}", popup.contentTypes.enabled(type), do (type=type) -> ->
      if @checked
        popup.contentTypes.enable type
      else
        popup.contentTypes.disable type