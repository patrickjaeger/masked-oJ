// requires OrientationJ plugin

#@ File (label="Select file", style = "file") file
#@ File (label="Select output directory", style = "directory") output

BFopen(file);
img_name_w_ext = getTitle();
img_name = File.nameWithoutExtension;
run("Z Project...", "projection=[Max Intensity]");
close(img_name_w_ext);
rename(img_name);

// the orientationJ kernel operates on a square grid; if the image in not square,
// and not devidable by the kernal size, one row at the edge will have weird results
// because an incomplete window was analyzed
//makeRectangle(65, 7, 1274, 1274);
//run("Crop");

channel = 3;  // SET ANALYIS CHANNEL HERE
Stack.setChannel(channel);

// Rotate manually
setTool("line");
waitForUser("Mark long axis, then press OK");
getLine(x1, y1, x2, y2, lineWidth);
dx = x2 - x1;
dy = y2 - y1;
angle_radians = atan2(dy, dx);
print(angle_radians);
angle_degrees = angle_radians* (180.0 / PI);
rotation_angle = 180-angle_degrees;
for (i = 0; i < 3; i++) {
  Stack.setChannel(i);
  run("Rotate... ", "angle=" + rotation_angle + " interpolation=None");
}
run("Select None");


// Create mask for ECM
Stack.setChannel(channel);
run("Duplicate...", "title=mask");
//setAutoThreshold("Otsu dark");
setThreshold(100, 65535);  // SET THRESHOLD HERE
run("Convert to Mask");
run("Erode");
run("Erode");
run("Dilate");
run("Dilate");

run("Analyze Particles...", "size=50-Infinity show=Overlay add");
getDimensions(width, height, channels, slices, frames);
newImage("mask-2", "8-bit black", width, height, 1);
setForegroundColor(255, 255, 255);
roiManager("Fill");
roiManager("reset");
close("mask");


// save coordinates of all pixels in the mask that are not black
selectWindow("mask-2");
getDimensions(width, height, channels, slices, frames);

for (y = 0; y < height; y++) {
    for (x = 0; x < width; x++) {
        value = getPixel(x, y);
        if (value > 0) {
          row = nResults;
          setResult("X", row, x);
          setResult("Y", row, y);
          setResult("Value", row, value);        
        }
    }
}
updateResults(); 
saveAs("Results", output + File.separator + img_name + "_mask.csv");
run("Clear Results");
run("Create Selection");
roiManager("add");
close("mask-2");


// the orientation map is more or less continuous; the grid size determines what
// values are exported. the image dimensions have to be devidable by the grid size
// to not get corrupt values
// for 1024x1024: 1    2    4    8   16   32   64  128  256  512 1024
selectWindow(img_name);
run("OrientationJ Vector Field", "tensor=8 gradient=0 radian=on " +
    "vectorgrid=16 vectorscale=30.0 vectortype=0 vectoroverlay=on vectortable=on ");

saveAs("Results", output + File.separator + img_name + ".csv");

// save image with vector field overlay
run("Duplicate...", "duplicate channels="+channel);
//run("Enhance Contrast", "saturated=0.35");
setMinAndMax(1, 1500);  // SET CONTRAST FOR VALIDATION IMAGE HERE
run("RGB Color");
roiManager("select", 0);
setForegroundColor(255, 255, 255);
run("Draw", "slice");

run("Size...", "width=700 height=700 depth=1 constrain average interpolation=Bilinear");

saveAs("PNG", output + File.separator + img_name +".png");

close(img_name + ".csv");
close("*");
roiManager("reset");


function BFopen(file) { 
  // Open input using the bioformats importer
  run("Bio-Formats Importer", 
  "open=[" + file + 
  "] autoscale color_mode=Default rois_import=[ROI manager] specify_range" +
  " view=Hyperstack stack_order=XYCZT");
}