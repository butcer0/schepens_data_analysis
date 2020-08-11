// Title:PER CELL NUCLEI COUNTER 
// Revision version: 1.0 - 07/04/2020
// First version: 1.0 - 07/04/2020 

// Description: This macro performs retinal layer cell segmentation and fluorescent-labeled cell
// nuceli quantitation 
//------------------------------------
// Authors: Erik Butcher
// Schepens Eye Research Institute
// Massachusetts Eye and Ear Infirmary
// Harvard Medical School
// 20 Staniford St, Boston, MA (02114)
// Unites States of America
// Website: 
//------------------------------------
// Note: Please review instructions before use!
//---------------------------------------------------------------------------------

// DIALOG
	var Website = "https://researchers.masseyeandear.org/details/342";
	var Input_Folder = 0;
	var Threshold_Folder = 0;
	var Images = 0;
	var Cell_Stain_Channel = 0;
	var Nuclei_Stain_Channel = 0;
	var Do_Measure_ROIs = 0;
	var Do_Count_Nuclei = 0;
	var Is_Single_Channel_Mode = 0;
	var Do_Batch_Mode = 0;
	
	// Cell Dialog
	var Maxima_Tolerance = 30;
	var Stroke_Color_Dialog_Selections = newArray("Random", "cyan", "red", "blue", "green", "magenta", "orange", "red", "white", "yellow", "black");
	var Stroke_Color_Selections = newArray("cyan", "red", "blue", "green", "magenta", "orange", "red", "white", "yellow", "black");
	var Stroke_Color = "cyan";
	var Stroke_Color_Is_Random = false;
	var Cell_Median_Radius = 6;
	var Cell_Background_Subtract_Radius = 125;
	var Exclude_On_Edges = false;
	
	// Nuclei Dialog
	var Nuclei_Median_Radius = 13;
	var Nuclei_Subtract_Background_Rolling = 13;
	var Nuclei_Subtract_Background_Do_Add = true;

// SETUP
	var dir = 0;
	var name = 0;
	var path = 0;
	var path2 = 0;
	var w = 0;
	var h = 0;
	var Stack_ID = 0;
	var Green_ID = 0;
	var Red_ID = 0;
	var Blue_ID = 0;
	var Cell_Stain_ID = 0;
	var Nuclei_Stain_ID = 0;

// MACRO
Html = "<html>"
     +"Visit us at: <a href='https://researchers.masseyeandear.org/details/342'><h1>https://researchers.masseyeandear.org/details/342</h1></a>"

Input_Folder = getDirectory("Choose a Directory");

Dialog.create("Per Cell Nuclei Counter - 1 Channel Images");
Dialog.addMessage("Imaging Folder: "+Input_Folder);
Dialog.addChoice("Quantification Mode", newArray("Auto", "Custom"));
Dialog.addChoice("Cell Stain Channel", newArray("Green", "Blue", "Red", "Generate"));
Dialog.addChoice("Nuclei Channel", newArray("Blue", "Green", "Red"));
Dialog.addChoice("Marker Color", Stroke_Color_Dialog_Selections);
Dialog.addCheckbox("Single Channel Mode", false);
Dialog.addCheckbox("Nuclei Morphology Analysis", true);
Dialog.addCheckbox("Nuclei Per Cell Count", false);
Dialog.addCheckbox("Silent Mode", false);
Dialog.addHelp(Html);
Dialog.show();

run_mode = Dialog.getChoice();
Cell_Stain_Channel = Dialog.getChoice();
Nuclei_Stain_Channel = Dialog.getChoice();
stroke_Choice = Dialog.getChoice();
Is_Single_Channel_Mode = Dialog.getCheckbox();
Do_Measure_ROIs = Dialog.getCheckbox();
Do_Count_Nuclei = Dialog.getCheckbox();
Do_Batch_Mode = Dialog.getCheckbox();
if(stroke_Choice == "Random") {
	Stroke_Color_Is_Random = true;
} else {
	Stroke_Color = stroke_Choice;
}
print("\\Clear");
if (run_mode == "Custom") {
	ShowCustomRunDialog();
}

RunAnalysis();

//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//FUNCTIONS

function ShowCustomRunDialog() {
	// todo: introduce random marker color to easily identify when an analysis has changed
	
	cell_segmentation_label="Cell Segmentation";
	nuclei_segmentation_label="Nuclei Segmentation and Quantification";
	Dialog.create("Per Cell Nuclei Counter");
	Dialog.addMessage("        " + cell_segmentation_label);
	Dialog.addSlider("Maxima_Tolerance (microns2):", 0, 50, Maxima_Tolerance);
	Dialog.addSlider("Median Radius (microns):", 0, 50, Cell_Median_Radius);
	Dialog.addSlider("Background Subtract Radius (Cell) (microns2):", 0, 300, Cell_Background_Subtract_Radius);
	Dialog.addMessage(" ");
	Dialog.addMessage("        " + nuclei_segmentation_label);
	Dialog.addSlider("Median Radius (microns2):", 0, 50, Nuclei_Median_Radius);
	Dialog.addSlider("Subtract Background Rolling (microns):", 0, 50, Nuclei_Subtract_Background_Rolling);
	Dialog.addCheckbox("Subtract Background Add Mode?", Nuclei_Subtract_Background_Do_Add);
	Dialog.addCheckbox("Exclude on Edges?", Exclude_On_Edges);
	Dialog.addHelp(Html);
	Dialog.show();

	Maxima_Tolerance = Dialog.getNumber();
	Cell_Median_Radius = Dialog.getNumber();
	Cell_Background_Subtract_Radius = Dialog.getNumber();
	Nuclei_Median_Radius = Dialog.getNumber();
	Nuclei_Subtract_Background_Rolling = Dialog.getNumber();
	Nuclei_Subtract_Background_Do_Add = Dialog.getCheckbox();
}

function RunAnalysis() {
//	CreateThresholdedFolder();
	if (Do_Batch_Mode) {
		setBatchMode(true); //batch mode
	}
	
	Images = getFileList(Input_Folder);
	for (i=0; i<Images.length; i++) {
		
		if (Is_Single_Channel_Mode) {
			SingleChannelSplitAndSetChannels();
		} else {
			SplitAndSetChannels();
		}
		
		Setup();
		selectImage(Cell_Stain_ID);
		SegmentCellStainChannel();
		ReindexROINumbers();
		selectImage(Nuclei_Stain_ID);
		if (Do_Measure_ROIs) {
			MeasureROIs();
		}
		
		if (Do_Count_Nuclei) {
			SegmentAndQuantifyNucleiChannel();
		}

		if (Cell_Stain_ID != Nuclei_Stain_ID) {
			selectImage(Cell_Stain_ID);
			close();
			selectImage(Nuclei_Stain_ID);
			close();
		} else {
			selectImage(Nuclei_Stain_ID);
			close();
		}
	}
	
	if (Do_Batch_Mode) {
		setBatchMode(false); //batch mode
	}
}

function CreateThresholdedFolder() {
	Thresholded_Folder = Input_Folder + "/thresholded/";
	File.makeDirectory(Thresholded_Folder);
}

function SingleChannelSplitAndSetChannels() {
	inputPath= Input_Folder + Images[i];
    open(inputPath);
    image_Stack_Title = getTitle;
    Stack_ID = getImageID();
	Nuclei_Stain_ID = Stack_ID;
	GenerateStainChannel();
}

function SplitAndSetChannels() {
    inputPath= Input_Folder + Images[i];
    open(inputPath);
    image_Stack_Title = getTitle;
    Stack_ID = getImageID();
    print("Splitting Image: " + image_Stack_Title);        
    run("Split Channels");
    if (isOpen("C1-"+image_Stack_Title)) {
		selectWindow("C1-"+image_Stack_Title);
		Blue_ID = getImageID();	
    }

    if (isOpen("C2-"+image_Stack_Title)) {
		selectWindow("C2-"+image_Stack_Title);
		Green_ID = getImageID();
    }

    if (isOpen("C3-"+image_Stack_Title)) {
    	selectWindow("C3-"+image_Stack_Title);
		Red_ID = getImageID();
	//	close();
    }	
    		
	SetNucleiStainChannel();
	SetCellStainChannel();
	//CloseUnusedChannel();
    selectImage(Cell_Stain_ID);
    write("Split Complete and Channels Set");   
}

function SetNucleiStainChannel() {				
	if (Nuclei_Stain_Channel == "Blue") {
		Nuclei_Stain_ID = Blue_ID;
	} else if (Nuclei_Stain_Channel == "Green") {
		Nuclei_Stain_ID = Green_ID;
	} else {
		Nuclei_Stain_ID = Red_ID;
	}
	print("Nuclei Stain Channel Selected: "+Nuclei_Stain_ID);
}

function SetCellStainChannel() {
	if (Cell_Stain_Channel == "Blue") {
		Cell_Stain_ID = Blue_ID;
	} else if (Cell_Stain_Channel == "Green") {
		Cell_Stain_ID = Green_ID;
	} else if (Cell_Stain_Channel == "Red") {
		Cell_Stain_ID = Red_ID;
	} else {
		GenerateStainChannel();
	}

	print("Cell Stain Channel Selected: "+Cell_Stain_ID);
}

function GenerateStainChannel() {
	selectImage(Nuclei_Stain_ID);
	run("Duplicate...", "title="+image_Stack_Title+" duplicate channels=1");
	Cell_Stain_ID = getImageID();
}

function CloseUnusedChannel() {
	if (Cell_Stain_Channel != Blue_ID && Nuclei_Stain_Channel != Blue_ID) {
		selectImage(Blue_ID);
	} else if (Cell_Stain_Channel != Green_ID && Nuclei_Stain_Channel != Green_ID) {
		selectImage(Green_ID);
	} else {
		selectImage(Red_ID);
	}
	close();
	print("Closed Unused Channel");
}

function Setup() {
	run("8-bit");
	if(Stroke_Color_Is_Random) {
		updateStrokeColorRandomly();
	}
	run("Overlay Options...", "stroke="+Stroke_Color+" width=1 fill=none set");
}

function updateStrokeColorRandomly() {
	Stroke_Color = Stroke_Color_Selections[randomInt(Stroke_Color_Selections.length-1)];
}

function randomInt(n) {
   return n * random();
}

function SegmentCellStainChannel() {
	run("Median...", "radius="+Cell_Median_Radius);
	run("Subtract Background...", "rolling="+Cell_Background_Subtract_Radius+" sliding");
	run("Auto Threshold", "method=Default white");
	roiManager("Reset");
	//run("Analyze Particles...", "pixel exclude clear add");
	//run("Analyze Particles...", "pixel clear add");
	if(Exclude_On_Edges) {
		run("Analyze Particles...", "pixel exclude add");	
	}
	else {
		run("Analyze Particles...", "pixel add");	
	}
	
}

function ReindexROINumbers() {
	for(i=0; i<roiManager("count"); i++) {
		roiManager("select", i);
		roiManager("Rename", i);
	}
}

function MeasureROIs() {
	run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None*");
	for(i=0; i<roiManager("count"); i++) {
		roiManager("select", i);		
		roiManager("Measure")
		var mean_value = Table.getColumn("Mean");
//		setResult("Mean 2", i, mean_value[i]);
//		print("Found Mean: "+ mean_value[i]);
	}
}

function SegmentAndQuantifyNucleiChannel() {
	run("8-bit");

	//Archive:
	//run("Gaussian Blur...", "sigma=1");
	//run("Subtract Background...", "rolling=25");
	//run("Median...", "radius=6");
	//run("Median...", "radius="+Nuclei_Median_Radius);
	//run("Subtract Background...", "rolling=125 sliding");
	//run("Subtract Background...", "rolling="+Nuclei_Subtract_Background_Rolling+" create");
	//run("Auto Threshold", "method=Default white");
	//run("Watershed");
	
	run("Median...", "radius="+Nuclei_Median_Radius);
	run("Subtract Background...", "rolling="+Nuclei_Subtract_Background_Rolling+" create");
	run("Auto Threshold", "method=Default white");
	run("Watershed");
// if using single channel -> duplicate then use that as the second

	for(i=0; i<roiManager("count"); i++) {
		roiManager("select", i);		
		run("Find Maxima...", "noise="+Maxima_Tolerance+" output=[Count]");
		run("Find Maxima...", "noise="+Maxima_Tolerance+" output=[Point Selection]");
		run("Add Selection...");
	}
}

function MeasureAndQuantifyROIs() {
	for(i=0; i<roiManager("count"); i++) {
		roiManager("select", i);		
		roiManager("Measure")
		var mean_value = Table.getColumn("Mean");
//		setResult("Mean 2", i, mean_value[i]);
//		print("Found Mean: "+ mean_value[i]);
	}
	run("Median...", "radius="+Nuclei_Median_Radius);
	run("Subtract Background...", "rolling="+Nuclei_Subtract_Background_Rolling+" create");
	run("Auto Threshold", "method=Default white");
	run("Watershed");

	for(i=0; i<roiManager("count"); i++) {
		roiManager("select", i);		
		run("Find Maxima...", "noise="+Maxima_Tolerance+" output=[Count]");
		run("Find Maxima...", "noise="+Maxima_Tolerance+" output=[Point Selection]");
		run("Add Selection...");
	}
}

function SaveResults() {
	
}

function SaveSummary() {
	
}
//------------------------------------
// Note: Original Raw Code
//---------------------------------------------------------------------------------
function originalCode() {
	var tolerance = 30;
	
	originalImage = getTitle();
	run("8-bit");
	run("Overlay Options...", "stroke=red width=1 fill=none set");
	run("Median...", "radius=6");
	run("Subtract Background...", "rolling=125 sliding");
	run("Auto Threshold", "method=Default white");
	roiManager("Reset");
	//run("Analyze Particles...", "pixel exclude clear add");
	//run("Analyze Particles...", "pixel clear add");
	run("Analyze Particles...", "pixel add");
	
	waitForUser("Select the image for spot counting");
	run("8-bit");
	
	//run("Gaussian Blur...", "sigma=1");
	//run("Subtract Background...", "rolling=25");
	//run("Median...", "radius=6");
	run("Median...", "radius=13");
	//run("Subtract Background...", "rolling=125 sliding");
	run("Subtract Background...", "rolling=13 create");
	run("Auto Threshold", "method=Default white");
	run("Watershed");

	// attempting the append
	roiManager("Deselect");
	run("Set Measurements...", "shape redirect=None decimal=3");
	
	for(i=0; i<roiManager("count"); i++) {
		roiManager("select", i);
		roiManager("Measure")
		mean_value = Table.getColumn("Mean");
		setResult("Mean", i, mean_value);
		print("Found Mean: "+ mean_value);
//		run("Find Maxima...", "noise="+tolerance+" output=[Count]");
//		run("Find Maxima...", "noise="+tolerance+" output=[Point Selection]");
//		run("Add Selection...");
	}
}
