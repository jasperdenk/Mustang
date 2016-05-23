component extends="framework.zero"
{
  this.root = getDirectoryFromPath( getBaseTemplatePath()) & "../..";
  this.configFiles = this.root & "/config";

  this.defaultConfig["fallBackImage"] = expandPath( "../inc/img/noimg.png" );
  this.defaultConfig["imageSizes"] = {
    "large"   = [1000,500],
    "medium"  = [250,250],
    "small"   = [100,100],
    "logo"    = [200,100],
    "pdflogo" = [500,300],
    "square"  = [216]
  };

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  public void function onApplicationStart(){
    super.onApplicationStart();
    application.jl = new javaloader.JavaLoader( ["#this.root#/lib/java/java-image-scaling-0.8.5.jar"] );
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  public void function onRequestStart(){
    super.onRequestStart();
    variables.jl = application.jl;
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  public void function onRequest(){
    param url.src = "";
    param url.size = "large";
    param url.quality = 0.8;

    if( !structKeyExists( variables.config.imageSizes, url.size )){
      throw( message = "Invalid size");
    }

    var imageName = listFirst( trim( url.src ), "/" );
    var sourcePath = "#variables.config.fileUploads#/temp/#imageName#";
    var destinationPath = "#variables.config.fileUploads#/resized/#url.size#-#imageName#";
    var resized = 0;

    // image not found:
    if( !fileExists( sourcePath )){
      writeToBrowser( fileReadBinary( variables.config.fallBackImage ));
    }

    // cached image found:
    if( fileExists( destinationPath ) && !structKeyExists( url, "reload" )){
      writeToBrowser( fileReadBinary( destinationPath ));
    }

    var sourceImage = imageNew( sourcePath );

    // setup resize actions:
    switch( url.size ){
      case "square":
        resized = __processSquare( sourceImage );
        break;

      default:
        resized = resize( sourceImage, variables.config.imageSizes[url.size][1], variables.config.imageSizes[url.size][2] );
    }

    // compress image:
    var compressedImage = compress( resized, url.quality );

    // save to disk, for cache purpose:
    fileWrite( destinationPath, compressedImage );

    // finally, write file to browser:
    writeToBrowser( compressedImage );
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  private any function resize( required any sourceImage, required string width = "", required string height = "", method = "default" ){
    var d = {
      width = int( val( width )),
      height = int( val( height ))
    };
    
    
    // http://www.giancarlogomez.com/2013/08/how-to-fix-orientation-issue-with-ios.html
    orientation = imageGetEXIFTag( sourceImage, 'orientation');
     
    // there is an orientation so lets check it to see what we need to do
    // if isNull() is not available in your version of ColdFusion 
    // use ImageGetEXIFMetadata and then check if the structKeyExists
    if(!isNull(orientation)){     
      // look to see if the orientation value tells us there is 
      // a rotation on it (by looking for the string value)
      hasRotate = findNoCase('rotate',orientation);
      
      /*
      * it did find it so lets copy the image so the Exif Data is removed for the new image
      * If not on your phone or desktop (mac) the image will still respect the orientation message
      * even after we fix it, making it appear wrong
      */
      if (hasRotate){
        // strip out all text in the orientation value to get the degree of orientation
        rotateValue = reReplace(orientation,'[^0-9]','','all');
        // copy the image to remove the exif data
        sourceImage = imageCopy(sourceImage,0,0,sourceImage.width,sourceImage.height);
        // rotate image
        imageRotate(sourceImage,rotateValue);
      }
    }

    // in case of square: provide a bigger image to crop later on:
    if( width == "" || height == "" ){
      if( width == "" ){
        d.width = height;
        d.height = ( sourceImage.height / sourceImage.width ) * height;
      }else{
        d.width = ( sourceImage.width / sourceImage.height ) * width;
        d.height = width;
      }
    }

    var bufferedImage = imageGetBufferedImage( sourceImage );

    switch( method )
    {
      case "force": // (distorts the image)
        var resampleOp = variables.jl.create( "com.mortennobel.imagescaling.ResampleOp" );
        return resampleOp.init( d.width, d.height ).filter( bufferedImage, nil());
        break;

      case "thumbnail":
        var dimensionConstrain = variables.jl.create( "com.mortennobel.imagescaling.DimensionConstrain" );
        var thumpnailRescaleOp = variables.jl.create( "com.mortennobel.imagescaling.ThumpnailRescaleOp" );
        return thumpnailRescaleOp.init( dimensionConstrain.createMaxDimension( d.width, d.height )).filter( bufferedImage, nil());

      default: // ToFit
        var dimensionConstrain = variables.jl.create( "com.mortennobel.imagescaling.DimensionConstrain" );
        var resampleOp = variables.jl.create( "com.mortennobel.imagescaling.ResampleOp" );
        return resampleOp.init( dimensionConstrain.createMaxDimension( d.width, d.height )).filter( bufferedImage, nil());
        break;
    }
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  private binary function compress( required alteredImage, numeric quality = 0.8 ){
    var byteArrayOutputStream = createObject( "java", "java.io.ByteArrayOutputStream" ).init();
    var imageOutputStream = createObject( "java", "javax.imageio.stream.MemoryCacheImageOutputStream" ).init( byteArrayOutputStream );

    var imageIO = createObject( "java", "javax.imageio.ImageIO" );
    var JPEGWriter = imageIO.getImageWritersByFormatName( "jpg" ).next();
        JPEGWriter.setOutput( imageOutputStream );

    var JPEGWriterParam = createObject( "java", "javax.imageio.plugins.jpeg.JPEGImageWriteParam" ).init( nil());
        JPEGWriterParam.setCompressionMode( JPEGWriterParam.MODE_EXPLICIT );
        JPEGWriterParam.setCompressionQuality( quality );

    var IIOImage = createObject( "java", "javax.imageio.IIOImage" );
    var outputImage = IIOImage.init( alteredImage, nil(), nil());

    JPEGWriter.write( nil(), outputImage, JPEGWriterParam );
    JPEGWriter.dispose();

    return byteArrayOutputStream.toByteArray();
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  private void function writeToBrowser( required binary compressedImage ){
    var imageIO = createObject( "java", "javax.imageio.ImageIO" );
    var byteArrayInputStream = createObject( "java", "java.io.ByteArrayInputStream" ).init( compressedImage );

    finishedImage = imageIO.read( byteArrayInputStream );

    var response = getPageContext().getFusionContext().getResponse();
        response.setHeader( "Content-Type", "image/jpg" );

    var outputStream = response.getResponse().getOutputStream();

    imageIO.write( finishedImage, "jpg", outputStream );
    abort;
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  private any function __processSquare( sourceImage ){
    var type = "square";

    if( sourceImage.width > sourceImage.height ){
      resized = resize( sourceImage, variables.config.imageSizes[type][1], "", "thumbnail" );
    } else {
      resized = resize( sourceImage, "", variables.config.imageSizes[type][1], "thumbnail" );
    }

    var crop = [
      int(( resized.width / 2 - variables.config.imageSizes[type][1] / 2 )),
      int(( resized.height / 2 - variables.config.imageSizes[type][1] / 2 )),
      int( variables.config.imageSizes[type][1] ),
      int( variables.config.imageSizes[type][1] )
    ];

    return resized.getSubimage( crop[1], crop[2], crop[3], crop[4] );
  }
}