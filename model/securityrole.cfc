component extends="basecfc.base"
          persistent=true
          cacheuse="read-only"
          hide=true
{
  property fieldType="column"  inform="true" orderinform="1" editable="true" inlist="true" name="name" type="string" ORMType="string" length="32";
  property fieldType="column"  inform="true" orderinform="2" editable="true" inlist="true" name="loginscript" type="string" ORMType="string" length="128";
  property fieldType="column"  inform="true" orderinform="3" editable="true" name="menulist" type="string" ORMType="string" length="256";

  property fieldtype="one-to-many" name="contacts" singularName="contact" cfc="root.model.contact" FKColumn="securityroleid" cascade="delete-orphan" lazy="false" where="deleted!='true'";
  property fieldtype="one-to-many" name="securityroleitems" singularName="securityroleitem" cfc="root.model.securityroleitem" FKColumn="securityroleid" lazy="false" orderby="section" where="deleted!='true'" inform=1 editable=1 inlineedit=1;
  property persistent=0 name="canAccessAdmin" inlist=1;

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  public boolean function getCanAccessAdmin()
  {
    return isAdmin();
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  public boolean function isAdmin()
  {
    return getName() eq "Administrator";
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  public boolean function can( string action="", string section="" )
  {
    if( isAdmin())
    {
      return true;
    }

    if( not structKeyExists( session, "can" ))
    {
      session["can"] = {};
    }

    if( not (
          structKeyExists( session.can, "#action#-#section#" ) and
          isBoolean( session.can["#action#-#section#"] )
        ))
    {
      session.can["#action#-#section#"] = checkRight( action, section );
    }

    return session.can["#action#-#section#"];
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  public boolean function checkRight( string action="", string section="" )
  {
    var params = {
      "securityrole" = this,
      "section" = arguments.section
    };

    for( local.action in listToArray( arguments.action ))
    {
      params[local.action] = true;
    }

    var findSecurityRoleItem = entityLoad( "securityroleitem", params );

    return ( arrayLen( findSecurityRoleItem ) gt 0 );
  }
}