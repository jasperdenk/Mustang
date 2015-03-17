<cfcomponent output="false">
  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="init"><cfreturn this /></cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="nil" access="public" output="false" returntype="void"></cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="parseStringVariables" output="false">
    <cfargument name="stringToParse" type="string" required="true" />
    <cfargument name="stringVariables" type="struct" default="#{}#" required="false" />

    <cfif not isDefined( "stringVariables" ) or not structCount( stringVariables )>
      <cfreturn stringToParse />
    </cfif>

    <cfloop collection="#stringVariables#" item="local.key">
      <cfif not isNull( stringVariables[local.key] )>
        <cfset stringToParse = replaceNoCase( stringToParse, '###local.key###', stringVariables[local.key], 'all' ) />
      </cfif>
    </cfloop>

    <cfreturn stringToParse />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="setCookie" access="public" returnType="void" output="false">
    <cfargument name="name" type="string" required="true">
    <cfargument name="value" type="string" required="false">
    <cfargument name="expires" type="any" required="false">
    <cfargument name="domain" type="string" required="false">
    <cfargument name="httpOnly" type="boolean" required="false">
    <cfargument name="path" type="string" required="false">
    <cfargument name="secure" type="boolean" required="false">

    <cfset var args = {}>
    <cfset var arg = "">

    <cfloop item="arg" collection="#arguments#">
      <cfif not isNull(arguments[arg])>
        <cfset args[arg] = arguments[arg]>
      </cfif>
    </cfloop>

    <cfcookie attributecollection="#args#">
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="limiter">
    <cfargument name="duration" type="numeric" default=3>
    <cfargument name="count" type="numeric" default=6>
    <cfset var cacheId = "rate_limiter_" & CGI.REMOTE_ADDR>
    <cfset var rate = cacheGet(cacheId)>

    <cfif isNull(rate)>
        <!--- Create cached object --->
        <cfset cachePut(cacheID, {attempts = 1, start = Now()}, createTimeSpan(0,0,1,0))>
    <cfelseif DateDiff("s", rate.start, Now()) LT arguments.duration>
        <cfif rate.attempts gte arguments.count>
            <cfoutput>
                <p>You are making too many requests too fast,
                please slow down and wait #arguments.duration# seconds</p>
            </cfoutput>
            <cfheader statuscode="503" statustext="Service Unavailable">
            <cfheader name="Retry-After" value="#arguments.duration#">
            <cflog file="limiter" text="#cgi.remote_addr# #rate.attempts# #cgi.request_method# #cgi.SCRIPT_NAME# #cgi.QUERY_STRING# #cgi.http_user_agent# #rate.start#">
            <cfif rate.attempts is arguments.count>
                <!--- Lock out for duration --->
                <cfset cachePut(cacheID, {attempts = rate.attempts + 1, start = Now()}, createTimeSpan(0,0,1,0))>
            </cfif>
            <cfabort>
        <cfelse>
            <!--- Increment attempts --->
            <cfset cachePut(cacheID, {attempts = rate.attempts + 1, start = rate.start}, createTimeSpan(0,0,1,0))>
        </cfif>
    <cfelse>
        <!--- Reset attempts --->
        <cfset cachePut(cacheID, {attempts = 1, start = Now()}, createTimeSpan(0,0,1,0))>
    </cfif>
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="getRandomColor" access="public" output="false" returnType="string">
    <cfreturn "##" &
      right( "0" & formatBaseN( randRange( 0, 255 ), 16 ), 2 ) &
      right( "0" & formatBaseN( randRange( 0, 255 ), 16 ), 2 ) &
      right( "0" & formatBaseN( randRange( 0, 255 ), 16 ), 2 ) />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="getCountryList" access="public" output="false" returnType="array">
    <cfreturn entityLoad( "country" ) />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="cmToPoints" returntype="numeric" access="public" output="false" hint="Converts centimeters to PostScript points">
    <cfargument name="centimeters" type="numeric" required="true">
    <cfreturn ( arguments.centimeters * 72 ) / 2.54>
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="authIsValid" output="false">
    <cfargument name="auth" required="true" />

    <cfset var requiredKeys = [ 'isLoggedIn', 'user', 'userid', 'role' ] />

    <cfloop array="#requiredKeys#" index="key">
      <cfif not structKeyExists( auth, key )>
        <cfreturn false />
      </cfif>
    </cfloop>

    <cfif not len( trim( auth.userid ))><cfreturn false /></cfif>
    <cfif not isStruct( auth.user )><cfreturn false /></cfif>
    <cfif not isStruct( auth.role )><cfreturn false /></cfif>
    <cfif not isBoolean( auth.isLoggedIn )><cfreturn false /></cfif>

    <cfreturn true />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="hashPassword" access="public" output="false" returnType="string">
    <cfargument name="password" required="true" />

    <cfset var salt = generatePassword( 16 ) />

    <cfreturn hash( arguments.password & salt, 'SHA-512' ) & salt />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="comparePassword" access="public" output="false" returnType="boolean">
    <cfargument name="password" required="true" />
    <cfargument name="storedPW" required="true" />

    <cfset var storedsalt = right( arguments.storedPW, 16 ) />

    <cfreturn 0 eq compare( arguments.storedPW, hash( arguments.password & storedsalt, 'SHA-512' ) & storedsalt ) />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="createSession">
    <cflock scope="session" type="exclusive" timeout="30">
      <cfset session.can = {} />
      <cfset session.auth = {
        "isLoggedIn" = false,
        "user" = 0,
        "role" = 0,
        "userid" = '',
        "canAccessAdmin" = false
      } />
    </cflock>
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="refreshSession" returnType="boolean">
    <cfargument name="userid" required="false" />
    <cfargument name="username" required="false" />

    <cfif structKeyExists( arguments, "username" ) and len( trim( arguments.username ))>
      <cfset local.user = entityLoad( "contact", { username = arguments.username }, true ) />
    <cfelseif structKeyExists( arguments, "userid" ) and len( trim( arguments.userid ))>
      <cfset local.user = entityLoadByPK( "contact", arguments.userid ) />
    <cfelse>
      <cfreturn false />
    </cfif>

    <cfif isNull( local.user )>
      <cfreturn false />
    </cfif>

    <cfset createSession() />

    <cflock scope="session" type="exclusive" timeout="30">
      <!--- populate user object with DB data --->
      <cfset session.auth.isLoggedIn = true />
      <cfset session.auth.user = local.user />
      <cfset session.auth.userid = local.user.getID() />
      <cfset session.auth.role = local.user.getSecurityrole() />
      <cfset session.auth.canAccessAdmin = local.user.getSecurityrole().getCanAccessAdmin() />
    </cflock>

    <cfreturn true />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="csvToArray" access="public" output="false" returnType="array">
    <cfargument name="csv" required="true" />
    <cfargument name="delimiter" default="," />

    <cfset var strRegEx = "(""(?:[^""]|"""")*""|[^""#arguments.delimiter#\r\n]*)(#arguments.delimiter#|\r\n?|\n)?"/>
    <cfset var objPattern = createObject( "java", "java.util.regex.Pattern" ).Compile( javaCast( "string", strRegEx )) />
    <cfset var objMatcher = objPattern.Matcher( javaCast( "string", arguments.csv )) />
    <cfset var arrData = [[]] />

    <cfloop condition="objMatcher.Find()">
      <cfset local.value = objMatcher.Group( javaCast( "int", 1 )) />
      <cfset local.value = local.value.ReplaceAll( javaCast( "string", "^""|""$" ), javaCast( "string", "" )) />
      <cfset local.value = local.value.ReplaceAll( javaCast( "string", "(""){2}" ), javaCast( "string", "$1" )) />

      <cfset arrayAppend( arrData[ ArrayLen( arrData ) ], local.value ) />
      <cfset local.delimiter = objMatcher.Group( javaCast( "int", 2 )) />

      <cfif structKeyExists( local, "delimiter" )>
        <cfif local.delimiter neq arguments.delimiter>
          <cfset arrayAppend( arrData, [] ) />
        </cfif>
      <cfelse>
        <cfbreak />
      </cfif>
    </cfloop>

    <cfreturn arrData />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="generatePassword" access="public" output="false" returnType="string">
    <cfscript>
      var length        = 8;
      var type          = "uc,lc,num";

      var password      = "";
      var tmp_char      = "";
      var prev_char     = "";
      var lIllegelChars = "o,O,0,l,I,1,B,8";

      if( arrayLen( arguments ) gt 0 ) length = val( arguments[1] );  // >0
      if( arrayLen( arguments ) gt 1 ) type   = arguments[2];         // uc,lc,num,oth

      for( i=1; i lte length; i=i+1 )
      {

        while( true )
        {
          if(      randRange( 1, 4 ) eq 1 and listFindNoCase( type, 'uc'   )) tmp_char = chr( randRange( 65, 90 ));
          else if( randRange( 1, 4 ) eq 2 and listFindNoCase( type, 'lc'   )) tmp_char = chr( randRange( 97,122 ));
          else if( randRange( 1, 4 ) eq 3 and listFindNoCase( type, 'num'  )) tmp_char = chr( randRange( 48,57 ));
          else if( randRange( 1, 4 ) eq 4 and listFindNoCase( type, 'oth'  )) tmp_char = chr( randRange( 33,47 ));
          else
          {
            tmp_char = chr( 0 );
          }

          if( tmp_char neq chr( 0 )
              and not listFind( lIllegelChars, tmp_char )
              and tmp_char neq prev_char
            )
          {
            break;
          }
        }

        password = password & tmp_char;
        prev_char = tmp_char;
      }

      return password;
    </cfscript>
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="mjhStructFindKey">
    <cfargument name="struct" type="any" required="true" />
    <cfargument name="key" type="string" required="true" />
    <cfargument name="all" type="string" required="false" default="one" />
    <cfargument name="path" type="string" required="false" default="" />

    <cfset var result = [] />
    <cfset var newPath = "" />

    <cfif isArray( struct )>
      <cfset var arrayOfStructs = struct />
    <cfelse>
      <cfset var arrayOfStructs = [struct] />
    </cfif>

    <cfloop array="#arrayOfStructs#" index="local.structToCheck">
      <cfif not isStruct( local.structToCheck )>
        <cfcontinue />
      </cfif>

      <cfloop collection="#local.structToCheck#" item="local.k1">
        <cfset newPath = listAppend( path, local.k1, "." ) />
        <cfif local.k1 eq key>
          <cfset result = [{
            "owner" = local.structToCheck,
            "path" = "." & newPath,
            "value" = local.structToCheck[local.k1]
          }] />
        </cfif>

        <cfif isArray( local.structToCheck[local.k1] )>
          <cfloop from="1" to="#arrayLen( local.structToCheck[local.k1] )#" index="local.nr">
            <cfset local.foundOne = mjhStructFindKey( local.structToCheck[local.k1][local.nr], key, all, newPath & '[#local.nr#]' ) />

            <cfif isArray( local.foundOne ) and arrayLen( local.foundOne ) eq 1>
              <cfset local.foundOne = local.foundOne[1] />
            </cfif>

            <cfif isStruct( local.foundOne )>
              <cfset arrayAppend( result, local.foundOne ) />
              <cfif all neq "all">
                <cfreturn [local.foundOne] />
              </cfif>
            </cfif>
          </cfloop>
        </cfif>

        <cfif isStruct( local.structToCheck[local.k1] )>
          <cfset local.foundOne = mjhStructFindKey( local.structToCheck[local.k1], key, all, newPath ) />

          <cfif isArray( local.foundOne ) and arrayLen( local.foundOne ) eq 1>
            <cfset local.foundOne = local.foundOne[1] />
          </cfif>

          <cfif isStruct( local.foundOne )>
            <cfset arrayAppend( result, local.foundOne ) />
            <cfif all neq "all">
              <cfreturn [local.foundOne] />
            </cfif>
          </cfif>
        </cfif>
      </cfloop>
    </cfloop>

    <cfreturn result />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cffunction name="getByKeyValue">
    <cfargument name="object" hint="struct or array" required="true" />

    <cfargument name="key" />
    <cfargument name="value" />
    <cfargument name="operator" default="eq" />

    <cfset var result = [] />

    <cfif isStruct( object )>
      <cfset object = [object] />
    </cfif>

    <cfif not isArray( object )>
      <cfreturn "not an array" />
    </cfif>

    <cfloop array="#object#" index="local.objectToSearch">
      <cfset local.objectsWithThisKey = mjhStructFindKey( local.objectToSearch, key, 'all' ) />
      <cfloop array="#local.objectsWithThisKey#" index="local.objectWithThisKey">
        <cfif evaluate( "local.objectWithThisKey.owner[key] #operator# value" )>
          <cfset arrayAppend( result, local.objectWithThisKey.owner ) />
        </cfif>
      </cfloop>
    </cfloop>

    <cfif not arrayLen( result )>
      <cfreturn "no result" />
    </cfif>

    <cfif arrayLen( result ) eq 1>
      <cfreturn result[1] />
    </cfif>

    <cfreturn result />
  </cffunction>

  <!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
  <cfscript>
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    public any function jFloat( required string number )
    {
      return javaCast( "float", number );
    }

    /**
     * Convert a hexadecimal color into a RGB color value.
     *
     * @param hexColor   6 character hexadecimal color value.
     * @return Returns a string.
     * @author Eric Carlisle (&#101;&#114;&#105;&#99;&#99;&#64;&#110;&#99;&#46;&#114;&#114;&#46;&#99;&#111;&#109;)
     * @version 1.0, November 6, 2001
     */
    function HexToRGB(hexColor){
      /* Strip out poundsigns. */
      Var tHexColor = replace(hexColor,'##','','ALL');

      /* Establish vairable for RGB color. */
      Var RGBlist=[];
      Var RGPpart='';

      /* Initialize i */
      Var i=0;

      /* Loop through each hex triplet */
      for (i=1; i lte 5; i=i+2){
        RGBpart = InputBaseN(mid(tHexColor,i,2),16);
        arrayAppend(RGBlist,RGBpart);
      }
      return RGBlist;
    }

    /**
     * Sorts an array of structures based on a key in the structures.
     *
     * @param aofS   Array of structures. (Required)
     * @param key    Key to sort by. (Required)
     * @param sortOrder    Order to sort by, asc or desc. (Optional)
     * @param sortType   Text, textnocase, or numeric. (Optional)
     * @param delim    Delimiter used for temporary data storage. Must not exist in data. Defaults to a period. (Optional)
     * @return Returns a sorted array.
     * @author Nathan Dintenfass (&#110;&#97;&#116;&#104;&#97;&#110;&#64;&#99;&#104;&#97;&#110;&#103;&#101;&#109;&#101;&#100;&#105;&#97;&#46;&#99;&#111;&#109;)
     * @version 1, April 4, 2013
     */
    function arrayOfStructsSort(aOfS,key){
        //by default we'll use an ascending sort
        var sortOrder = "asc";
        //by default, we'll use a textnocase sort
        var sortType = "textnocase";
        //by default, use ascii character 30 as the delim
        var delim = ".";
        //make an array to hold the sort stuff
        var sortArray = arraynew(1);
        //make an array to return
        var returnArray = arraynew(1);
        //grab the number of elements in the array (used in the loops)
        var count = arrayLen(aOfS);
        //make a variable to use in the loop
        var ii = 1;
        //if there is a 3rd argument, set the sortOrder
        if(arraylen(arguments) GT 2)
          sortOrder = arguments[3];
        //if there is a 4th argument, set the sortType
        if(arraylen(arguments) GT 3)
          sortType = arguments[4];
        //if there is a 5th argument, set the delim
        if(arraylen(arguments) GT 4)
          delim = arguments[5];
        //loop over the array of structs, building the sortArray
        for(ii = 1; ii lte count; ii = ii + 1)
          sortArray[ii] = aOfS[ii][key] & delim & ii;
        //now sort the array
        arraySort(sortArray,sortType,sortOrder);
        //now build the return array
        for(ii = 1; ii lte count; ii = ii + 1)
          returnArray[ii] = aOfS[listLast(sortArray[ii],delim)];
        //return the array
        return returnArray;
    }

    /**
     * Displays how long ago something was.
     *
     * @param dateThen   Date to format. (Required)
     * @return Returns a string.
     * @author Alan McCollough (&#97;&#109;&#99;&#99;&#111;&#108;&#108;&#111;&#117;&#103;&#104;&#64;&#97;&#110;&#116;&#104;&#99;&#46;&#111;&#114;&#103;)
     * @version 1, December 7, 2009
     */
    function ago( dateThen )
    {
      var result = "";
      var i = "";
      var rightNow = Now();

      do
      {
        i = dateDiff('yyyy',dateThen,rightNow);
        if(i GTE 2){
          result = "#i# #request.context.i18n.translate( 'years' )# #request.context.i18n.translate( 'ago' )#";
        break;}
        else if (i EQ 1){
          result = "#i# #request.context.i18n.translate( 'year' )# #request.context.i18n.translate( 'ago' )#";
        break;}

        i = dateDiff('m',dateThen,rightNow);
        if(i GTE 2){
          result = "#i# #request.context.i18n.translate( 'months' )# #request.context.i18n.translate( 'ago' )#";
        break;}
        else if (i EQ 1){
          result = "#i# #request.context.i18n.translate( 'month' )# #request.context.i18n.translate( 'ago' )#";
        break;}

        i = dateDiff('d',dateThen,rightNow);
        if(i GTE 2){
          result = "#i# #request.context.i18n.translate( 'days' )# #request.context.i18n.translate( 'ago' )#";
        break;}
        else if (i EQ 1){
          result = "#i# #request.context.i18n.translate( 'day' )# #request.context.i18n.translate( 'ago' )#";
        break;}

        i = dateDiff('h',dateThen,rightNow);
        if(i GTE 2){
          result = "#i# #request.context.i18n.translate( 'hours' )# #request.context.i18n.translate( 'ago' )#";
        break;}
        else if (i EQ 1){
          result = "#i# #request.context.i18n.translate( 'hour' )# #request.context.i18n.translate( 'ago' )#";
        break;}

        i = dateDiff('n',dateThen,rightNow);
        if(i GTE 2){
          result = "#i# #request.context.i18n.translate( 'minutes' )# #request.context.i18n.translate( 'ago' )#";
        break;}
        else if (i EQ 1){
          result = "#i# #request.context.i18n.translate( 'minute' )# #request.context.i18n.translate( 'ago' )#";
        break;}

        i = dateDiff('s',dateThen,rightNow);
        if(i GTE 2){
          result = "#i# #request.context.i18n.translate( 'seconds' )# #request.context.i18n.translate( 'ago' )#";
        break;}
        else if (i EQ 1){
          result = "#i# #request.context.i18n.translate( 'second' )# #request.context.i18n.translate( 'ago' )#";
        break;}
        else{
          result = " #request.context.i18n.translate( 'less-than-1-second' )# #request.context.i18n.translate( 'ago' )#";
        break;
        }
      }
      while( 0 eq 0 );

      return result;
    }

    /**
     * Converts an RGB color value into a hexadecimal color value.
     *
     * @param r      Red value triplet (0-255)
     * @param g      Green value triplet (0-255)
     * @param b      Blue value triplet (0-255)
     * @return Returns a string.
     * @author Eric Carlisle (ericc@nc.rr.com)
     * @version 1, November 27, 2001
     */
    function RGBtoHex(r,g,b){
      Var hexColor="";
      Var hexPart = '';
      Var i=0;

      /* Loop through the Arguments array, containing the RGB triplets */
      for (i=1; i lte 3; i=i+1){
        /* Derive hex color part */
        hexPart = formatBaseN(Arguments[i],16);

        /* Pad with "0" if needed */
        if (len(hexPart) eq 1){
          hexPart = '0' & hexPart;
        }

        /* Add hex color part to hexadecimal color string */
        hexColor = hexColor & hexPart;
      }
      return hexColor;
    }
  </cfscript>
</cfcomponent>