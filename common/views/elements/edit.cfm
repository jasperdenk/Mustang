<cfparam name="local.data" default="#rc.data#" />
<cfparam name="local.entity" default="#rc.entity#" />
<cfparam name="local.columns" default="#rc.columns#" />
<cfparam name="local.editable" default="#rc.editable#" />
<cfparam name="local.hideDelete" default="#rc.hideDelete#" />
<cfparam name="local.formprepend" default="" />
<cfparam name="local.formappend" default="" />
<cfparam name="local.fieldOverride" default="" />
<cfparam name="local.namePrepend" default="#rc.namePrepend#" />
<cfparam name="local.modal" default="#rc.modal#" />
<cfparam name="local.inline" default="#rc.inline#" />
<cfparam name="local.canBeLogged" default="#rc.canBeLogged#" />

<cfif local.modal>
  <cfsetting showdebugoutput="false" />
</cfif>

<cfif not structKeyExists( local, "#local.entity#id" ) and structKeyExists( rc, "#local.entity#id" )>
  <cfset local["#local.entity#id"] = rc["#local.entity#id"] />
</cfif>

<cfoutput>
  <cfif getItem() eq "view" and rc.auth.role.can( "change", local.entity )>
    <a class="pull-right btn btn-primary" href="#buildURL( '.edit?#local.entity#id=#rc["#local.entity#id"]#' )#">#i18n.translate('edit')#</a>
  </cfif>

  <cfif not local.modal>
    <ul class="nav nav-tabs">
      <li class="active"><a href="##form-#local.entity#" data-toggle="tab">#i18n.translate( getItem())#</a></li>
      <cfif structKeyExists( rc, "#local.entity#id" ) and local.canBeLogged>
        <cfset local.log = entityLoad( "logentry", { entity = local.data }, "createDate DESC" ) />
        <cfif isDefined( "local.log" ) and arrayLen( local.log )>
          <li><a href="##changelog" data-toggle="tab">#i18n.translate('changelog')#</a></li>
        </cfif>
      </cfif>
    </ul>
    <div class="tab-content">
      <div class="whitespace"></div>
  </cfif>

  <div class="tab-pane active" id="form-#local.entity#">
    <cfif not local.inline>
      <form<cfif local.modal> action="javascript:void(0);"<cfelse> id="mainform" action="#buildURL('.save')#" method="post"</cfif> class="form-horizontal">
    </cfif>
      <cfif not local.modal>
        <input type="hidden" name="submitButton" value="" />
      </cfif>

      <cfif structKeyExists( rc, "returnto" )>
        <input type="hidden" name="returnto" value="#rc.returnto#" />
      </cfif>

      <cfif structKeyExists( local, "#local.entity#id" )>
        <input type="hidden" name="#local.entity#id" value="#local["#local.entity#id"]#" />
      </cfif>

      <cfif len( trim( local.formprepend ))>
        #local.formprepend#
      </cfif>

      <!--- search for many-to-one fields who's ID has been passed to this form, and include as hidden field --->
      <cfset local.propertiesWithFK = structFindValue( rc.properties, 'many-to-one', 'all' ) />
      <cfloop array="#local.propertiesWithFK#" index="local.property">
        <cfset local.property = local.property.owner />
        <cfif structKeyExists( rc, local.property.fkcolumn ) and len( trim( rc[local.property.fkcolumn] )) and not local.property.fkcolumn eq '#local.entity#id'>
          <input type="hidden" name="#local.property.fkcolumn#" value="#rc[local.property.fkcolumn]#" />
        </cfif>
      </cfloop>

      <cfset local.i = 0 />
      <cfloop array="#local.columns#" index="local.column">
        <cfset local.i++ />
        <cfset local.sharedClass = "form-group" />
        <cfset local.editableCheck = false />
        <cfif structKeyExists( local.column, "editable" ) and local.column.editable and local.editable and rc.auth.role.can( "change", local.entity )>
          <cfset local.editableCheck = true />
        </cfif>
        <cfif not local.editableCheck>
          <cfset local.sharedClass = listAppend( local.sharedClass, "display", " " ) />
        </cfif>
        <cfif structKeyExists( local.column, "affected" )>
          <cfset local.sharedClass = listAppend( local.sharedClass, "affected", " " ) />
          <cfset local.sharedClass = listAppend( local.sharedClass, local.column.name, " " ) />
        </cfif>
        <div class="#local.sharedClass#">
          <cfif structKeyExists( local.column, 'ORMType' ) and local.column.ORMType eq "boolean">
            <label for="#local.column.name#" class="col-lg-3 control-label"></label>
          <cfelse>
            <label for="#local.column.name#" class="col-lg-3 control-label">
              #i18n.translate( local.column.name )#
              <cfif isDefined( "local.column.hint" )>
                <i class="fa fa-question-circle" title="#i18n.translate( 'hint-#local.entity#-#local.column.name#' )#"></i>
              </cfif>
            </label>
          </cfif>
          <div class="col-lg-9">
            <cfif local.editableCheck>
              <cfset local.fieldparameters = {
                "column"      = local.column,
                "i"           = local.i,
                "namePrepend" = local.namePrepend
              } />
              #view( "common:elements/fieldedit", local.fieldparameters )#
            <cfelse>
              <cfset local.fieldparameters = {
                "data"    = local.data,
                "column"  = {
                              "data" = local.column,
                              "name" = local.column.name
                            }
              } />
              #view( "common:elements/fielddisplay", local.fieldparameters )#
            </cfif>
          </div>
        </div>
      </cfloop>

      <cfif len( trim( local.formappend ))>
        #local.formappend#
        <hr />
      </cfif>

      <cfif not local.modal>
        <div class="whitespace"></div>

        <cfif local.canBeLogged and local.editable and rc.config.log and rc.config.lognotes>
          <cfset local.logObject = entityNew( "logentry" ) />
          <cfset local.logFields = local.logObject.getInheritedProperties() />

          <div class="panel-group" id="collapseLogentries">
            <div class="panel panel-default">
              <div class="panel-heading">
                <h4 class="panel-title"><a data-toggle="collapse" data-parent="##collapseLogentries" href="##collapseLogentry"><span><i class="fa fa-caret-right text-muted"></i></span><span class="text-muted">#i18n.translate( 'logentry-addform' )#</span></a></h4>
              </div>
              <div id="collapseLogentry" class="panel-collapse collapse">
                <div class="panel-body">
                  <cfloop list="note" index="local.logField">
                    <cfset local.logFields[local.logField].saved = '' />
                    <cfset local.fieldEditProperties = {
                      column=local.logFields[local.logField],
                      i=local.i++,
                      namePrepend="logentry_",
                      idPrepend="logentry_"
                    } />
                    <div class="form-group">
                      <label for="logentry_#local.logField#" class="col-lg-3 control-label">#i18n.translate( 'logentry_' & local.logField )#</label>
                      <div class="col-lg-9">#view("common:elements/fieldedit",local.fieldEditProperties)#</div>
                    </div>
                  </cfloop>
                </div>
              </div>
            </div>
          </div>
        </cfif>

        <div class="form-group">
          <div class="col-lg-offset-3 col-lg-9">
            <cfif local.editable>
              <button type="button" class="btn btn-default cancel-button">#i18n.translate('cancel')#</button>
              <cfset local.submitButtons = [
               {
                 "value" = "save",
                 "modal" = ""
               }
              ] />
              <cfif structKeyExists( rc, 'submitButtons' ) and arrayLen( rc['submitButtons'] )>
                <cfset local.submitButtons = rc['submitButtons'] />
              </cfif>

              <cfloop array="#local.submitButtons#" index="local.submitButton">
                <cfif len( trim( local.submitButton.modal ) )>
                  <a data-toggle="modal" href="##confirm#local.submitButton.value#" data-name="#local.submitButton.value#" class="btn btn-primary #local.submitButton.value#-button" data-style="expand-right">#i18n.translate( local.submitButton.value )#</a>
                  <button type="submit" class="hidden" data-name="#local.submitButton.value#"></button>
                  #view('common:elements/modal',{name=local.submitButton.modal,yeslink=''})#
                <cfelse>
                  <button type="submit" data-name="#local.submitButton.value#" class="btn btn-primary #local.submitButton.value#-button" data-style="expand-right"><span class="ladda-label">#i18n.translate( local.submitButton.value )#</span></button>
                </cfif>
              </cfloop>
            <cfelse>
              <button type="button" class="btn btn-primary cancel-button">#i18n.translate('back')#</button>
            </cfif>
          </div>
        </div>

        <cfif structKeyExists( rc, "#local.entity#id" )>
          <cfif not local.hideDelete and local.editable>
            <hr />

            <cfif local.data.getDeleted() eq 1>
              <div class="form-group">
                <div class="col-lg-offset-3 col-lg-9">
                  <a data-toggle="modal" href="##confirmrestore" class="btn btn-success">#i18n.translate('btn-admin:#local.entity#.restore')#</a>
                </div>
              </div>
              #view('common:elements/modal',{name="restore",yeslink=buildURL('.restore','?#local.entity#id=#rc[local.entity&'id']#')})#
            <cfelse>
              <div class="form-group">
                <div class="col-lg-offset-3 col-lg-9">
                  <a data-toggle="modal" href="##confirmdelete" class="btn btn-danger">#i18n.translate('btn-admin:#local.entity#.delete')#</a>
                </div>
              </div>
              #view('common:elements/modal',{name="delete",yeslink=buildURL('.delete','?#local.entity#id=#rc[local.entity&'id']#')})#
            </cfif>
          </cfif>

          <cfif local.data.hasProperty( 'createDate' ) and isDate( local.data.getCreateDate())>
            <small class="footnotes">
              #i18n.translate( 'created' )#: 
              <cfif local.data.hasProperty( 'createContact' )>
                <cfset local.creator = local.data.getCreateContact() />
                <cfif isDefined( "local.creator" )>
                  #i18n.translate('created-by')#: <a href="mailto:#local.creator.getEmail()#">#local.creator.getFullname()#</a>
                  #i18n.translate('on')#
                </cfif>
              </cfif>
              #lsDateFormat( local.data.getCreateDate(), i18n.translate( 'defaults-dateformat-small' ))# #i18n.translate('at')# #lsTimeFormat( local.data.getCreateDate(), 'HH:mm:ss' )#.
              <cfif isDate(local.data.getUpdateDate()) and dateDiff( 's', local.data.getCreateDate(), local.data.getUpdateDate()) gt 1>
                <br />
                #i18n.translate( 'updated' )#: 
                <cfif local.data.hasProperty( 'updateContact' )>
                  <cfset local.updater = local.data.getUpdateContact() />
                  <cfif isDefined( "local.updater" )>
                    #i18n.translate('updated-by')#: <a href="mailto:#local.updater.getEmail()#">#local.updater.getFullname()#</a>
                    #i18n.translate('on')#
                  </cfif>
                </cfif>
                #lsDateFormat( local.data.getUpdateDate(), i18n.translate( 'defaults-dateformat-small' ))# #i18n.translate('at')# #lsTimeFormat( local.data.getUpdateDate(), 'HH:mm:ss' )#.
              </cfif>
            </small>
          </cfif>
        </cfif>
      </cfif>
      <cfif not local.modal>
        <div id="inlineedit-result"></div>
      </cfif>
    <cfif not local.inline>
      </form>
    </cfif>
  </div>

  <cfif not local.modal>
    <cfif structKeyExists( rc, "#local.entity#id" ) and local.canBeLogged>
      <cfif isDefined( "local.log" ) and arrayLen( local.log )>
        <div class="tab-pane" id="changelog">#view( 'common:elements/changelog', { activity = local.log, linkToEntity = false, notesInline = true })#</div>
      </cfif>
    </cfif>

    </div>
    <div class="modal fade" id="modal-dialog" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true"></div>
  </cfif>
</cfoutput>