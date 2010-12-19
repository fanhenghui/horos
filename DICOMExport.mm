/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "DICOMExport.h"
#import <OsiriX/DCM.h>
#import "BrowserController.h"
#import "dicomFile.h"
#import "DCMView.h"
#import "DCMPix.h"
#import "altivecFunctions.h"

@implementation DICOMExport

- (NSString*) seriesDescription
{
	return exportSeriesDescription;
}

- (void) setSeriesDescription: (NSString*) desc
{
	if( desc != exportSeriesDescription)
	{
		[exportSeriesDescription release];
		exportSeriesDescription = [desc retain];
	}
}

- (void) setSeriesNumber: (long) no
{
	if( exportSeriesNumber != no)
	{
		exportSeriesNumber = no;
		
		[exportSeriesUID release];
		DCMObject *dcmObject = [[[DCMObject alloc] init] autorelease];
		[dcmObject newSeriesInstanceUID];
		exportSeriesUID = [[dcmObject attributeValueWithName:@"SeriesInstanceUID"] retain];
	}
}

- (id)init
{
	self = [super init];
	if (self)
	{
		dcmSourcePath = nil;
		dcmDst = nil;
		
		data = nil;
		width = height = spp = bps = 0;
		
		image = nil;
		imageData = nil;
		freeImageData = NO;
		imageRepresentation = nil;
		
		ww = wl = -1;
		
		exportInstanceNumber = 1;
		exportSeriesNumber = 5000;
		
		#ifndef OSIRIX_LIGHT
		DCMObject *dcmObject = [[[DCMObject alloc] init] autorelease];
		[dcmObject newSeriesInstanceUID];
		exportSeriesUID = [[dcmObject attributeValueWithName:@"SeriesInstanceUID"] retain];
		exportSeriesDescription = @"OsiriX SC";
		[exportSeriesDescription retain];
		#endif
		
		spacingX = 0;
		spacingY = 0;
		sliceThickness = 0;
		sliceInterval = 0;
		slicePosition = 0;
		slope = 1;
		
		int i;
		for( i = 0; i < 6; i++) orientation[ i] = 0;
		for( i = 0; i < 3; i++) position[ i] = 0;
	}
	
	return self;
}

- (void) dealloc
{
	NSLog(@"DICOMExport released");
	
	if( localData)
		free( localData);
	localData = nil;
	
	[image release];
	[imageRepresentation release];
	if( freeImageData) free( imageData);

	[exportSeriesUID release];
	[exportSeriesDescription release];
	
	[dcmSourcePath release];
	[dcmDst release];
	
	[super dealloc];
}


- (void) setSourceFile:(NSString*) isource
{
	[dcmSourcePath release];
	dcmSourcePath = [isource retain];
}

- (void) setSigned: (BOOL) s
{
	isSigned = s;
}

- (void) setOffset: (int) o
{
	offset = o;
}

- (void) setSlope: (float) s
{
	slope = s;
}

- (long) setPixelData:		(unsigned char*) idata
		samplesPerPixel:	(int) ispp
		bitsPerSample:		(int) ibps
		width:				(long) iwidth
		height:				(long) iheight
{
	if( localData)
		free( localData);
	localData = nil;
	
	spp = ispp;
	bps = ibps;
	width = iwidth;
	height = iheight;
	data = idata;
	
	isSigned = NO;
	offset = -1024;
	
	if( spp == 4 && bps == 8)
	{
		localData = (unsigned char*) malloc( width * height * 3);
		if( localData)
		{
			spp = 3;
			
			for( int y = 0; y < height; y++)
			{
				for( int x = 0; x < width; x++)
				{
					localData[ 0 + x*3 + y*width*3] = data[ 0+ x*4 + y*width*4];
					localData[ 1 + x*3 + y*width*3] = data[ 1+ x*4 + y*width*4];
					localData[ 2 + x*3 + y*width*3] = data[ 2+ x*4 + y*width*4];
				}
			}
			
			data = localData;
		}
	}
	return 0;
}


- (long) setPixelData:		(unsigned char*) idata
		samplePerPixel:		(long) ispp
		bitsPerPixel:		(long) ibps
		width:				(long) iwidth
		height:				(long) iheight
{
	return [self setPixelData:idata samplesPerPixel:ispp bitsPerSample:ibps width:iwidth height:iheight];
}

- (long) setPixelNSImage:	(NSImage*) iimage
{
	if( image != iimage)
	{
		[image release];
		image = nil;
		
		[imageRepresentation release];
		imageRepresentation = nil;
		
		if( freeImageData) free( imageData);
		freeImageData = NO;
		imageData = nil;
		
		image = [iimage retain];
	}

	if( image)
	{
		NSData				*tiffRep = [image TIFFRepresentation];
		NSSize				imageSize;
		long				w, h, i;
		
		if( tiffRep)
		{
			imageRepresentation = [[NSBitmapImageRep alloc] initWithData:tiffRep];
			imageSize = [imageRepresentation size];
			
			w = imageSize.width;
			h = imageSize.height;
			
			if( [imageRepresentation bytesPerRow] != w)
			{
				imageData = (unsigned char*) malloc( h * w * [imageRepresentation samplesPerPixel]);
				freeImageData = YES;
				
				for( i = 0; i < height; i++)
				{
					memcpy( imageData + i * width * [imageRepresentation samplesPerPixel], [imageRepresentation bitmapData] + i * [imageRepresentation bytesPerRow], width * [imageRepresentation samplesPerPixel]);
				}
			}
			else imageData = [imageRepresentation bitmapData];
			
			return [self setPixelData:		imageData
						samplesPerPixel:	[imageRepresentation samplesPerPixel]
						bitsPerSample:		[imageRepresentation bitsPerPixel] / [imageRepresentation samplesPerPixel]
						width:				w
						height:				h];
		}
		else return -1;
	}
	else return -1;
}

- (void) setDefaultWWWL: (long) iww :(long) iwl
{
	wl = iwl;
	ww = iww;
}

- (void) setPixelSpacing: (float) x :(float) y;
{
	spacingX = x;
	spacingY = y;
}

- (void) setSliceThickness: (double) t
{
	sliceThickness = t;
}

- (void) setOrientation: (float*) o
{
	for( int i = 0; i < 6; i++) orientation[ i] = o[ i];
}

- (void) setPosition: (float*) p
{
	for( int i = 0; i < 3; i++) position[ i] = p[ i];
}

- (void) setSlicePosition: (float) p
{
	slicePosition = p;
}

- (void) setModalityAsSource: (BOOL) v
{
	modalityAsSource = v;
}

- (NSString*) writeDCMFile: (NSString*) dstPath
{
	return [self writeDCMFile: dstPath withExportDCM: nil];
}

- (NSString*) writeDCMFile: (NSString*) dstPath withExportDCM:(DCMExportPlugin*) dcmExport
{
	if( spp != 1 && spp != 3)
	{
		NSLog( @"**** DICOM Export: sample per pixel not supported: %d", spp);
		return nil;
	}
	
	if( spp == 3)
	{
		if( bps != 8)
		{
			NSLog( @"**** DICOM Export: for RGB images, only 8 bits per sample is supported: %d", bps);
			return nil;
		}
	}
	
	if( bps != 8 && bps != 16 && bps != 32)
	{
		NSLog( @"**** DICOM Export: unknown bits per sample: %d", bps);
		return nil;
	}
	
	if( width != 0 && height != 0 && data != nil)
	{
		@try
		{
			DCMCalendarDate *studyDate = nil, *studyTime = nil;
			DCMCalendarDate *acquisitionDate = nil, *acquisitionTime = nil;
			DCMCalendarDate *seriesDate = nil, *seriesTime = nil;
			DCMCalendarDate *contentDate = nil, *contentTime = nil;
			
			DCMObject *dcmObject = nil;
			NSString *patientName = nil, *patientID = nil, *studyDescription = nil, *studyUID = nil, *studyID = nil, *charSet = nil;
			NSNumber *seriesNumber = nil;
			unsigned char *squaredata = nil;
			
			seriesNumber = [NSNumber numberWithInt:exportSeriesNumber];
			
			if( dcmSourcePath)
			{
				if ([DicomFile isDICOMFile:dcmSourcePath])
				{
					dcmObject = [DCMObject objectWithContentsOfFile:dcmSourcePath decodingPixelData:NO];
					
					patientName = [dcmObject attributeValueWithName:@"PatientsName"];
					patientID = [dcmObject attributeValueWithName:@"PatientID"];
					studyDescription = [dcmObject attributeValueWithName:@"StudyDescription"];
					studyUID = [dcmObject attributeValueWithName:@"StudyInstanceUID"];
					studyID = [dcmObject attributeValueWithName:@"StudyID"];
					studyDate = [dcmObject attributeValueWithName:@"StudyDate"];
					studyTime = [dcmObject attributeValueWithName:@"StudyTime"];
					seriesDate = [dcmObject attributeValueWithName:@"SeriesDate"];
					seriesTime = [dcmObject attributeValueWithName:@"SeriesTime"];
					acquisitionDate = [dcmObject attributeValueWithName:@"AcquisitionDate"];
					acquisitionTime = [dcmObject attributeValueWithName:@"AcquisitionTime"];
					contentDate = [dcmObject attributeValueWithName:@"ContentDate"];
					contentTime = [dcmObject attributeValueWithName:@"ContentTime"];
					charSet = [dcmObject attributeValueWithName:@"SpecificCharacterSet"];
					
					if( [seriesNumber intValue] == -1)
					{
						seriesNumber = [dcmObject attributeValueWithName:@"SeriesNumber"];
					}
				}
				else if ([DicomFile isFVTiffFile:dcmSourcePath])
				{
					DicomFile* FVfile = [[DicomFile alloc] init:dcmSourcePath];

					patientName = [FVfile elementForKey:@"patientName"]; 
					patientID = [FVfile elementForKey:@"patientID"];
					studyDescription = @"DICOM from FV300";
					studyUID = [FVfile elementForKey:@"studyID"];
					studyID = [FVfile elementForKey:@"studyID"];
					studyDate = [DCMCalendarDate date];
					studyTime = [DCMCalendarDate date];
					
					[FVfile release];
				}
			}
			else
			{
				patientName = @"Anonymous";
				patientID = @"0";
				studyDescription = @"SC";
				studyUID = @"0.0.0.0";
				studyID = @"0";
				studyDate = [DCMCalendarDate date];
				studyTime = [DCMCalendarDate date];
			}
			
			if( spacingX != 0 && spacingY != 0)
			{
				if( spacingX != spacingY)	// Convert to square pixels
				{
					if( bps == 16)
					{
						vImage_Buffer	srcVimage, dstVimage;
						long			newHeight = ((float) height * spacingY) / spacingX;
						
						newHeight /= 2;
						newHeight *= 2;
						
						squaredata = (unsigned char*) malloc( newHeight * width * bps/8);
						
						float	*tempFloatSrc = (float*) malloc( height * width * sizeof( float));
						float	*tempFloatDst = (float*) malloc( newHeight * width * sizeof( float));
						
						if( squaredata != nil && tempFloatSrc != nil && tempFloatDst != nil)
						{
							long err;
							
							// Convert Source to float
							srcVimage.data = data;
							srcVimage.height =  height;
							srcVimage.width = width;
							srcVimage.rowBytes = width* bps/8;
							
							dstVimage.data = tempFloatSrc;
							dstVimage.height =  height;
							dstVimage.width = width;
							dstVimage.rowBytes = width*sizeof( float);
							
							if( isSigned)
								err = vImageConvert_16SToF(&srcVimage, &dstVimage, 0,  1, 0);
							else
								err = vImageConvert_16UToF(&srcVimage, &dstVimage, 0,  1, 0);
							
							// Scale the image
							srcVimage.data = tempFloatSrc;
							srcVimage.height =  height;
							srcVimage.width = width;
							srcVimage.rowBytes = width*sizeof( float);
							
							dstVimage.data = tempFloatDst;
							dstVimage.height =  newHeight;
							dstVimage.width = width;
							dstVimage.rowBytes = width*sizeof( float);
							
							err = vImageScale_PlanarF( &srcVimage, &dstVimage, nil, kvImageHighQualityResampling);
						//	if( err) NSLog(@"%d", err);
							
							// Convert Destination to 16 bits
							srcVimage.data = tempFloatDst;
							srcVimage.height =  newHeight;
							srcVimage.width = width;
							srcVimage.rowBytes = width*sizeof( float);
							
							dstVimage.data = squaredata;
							dstVimage.height =  newHeight;
							dstVimage.width = width;
							dstVimage.rowBytes = width* bps/8;
							
							if( isSigned)
								err = vImageConvert_FTo16S( &srcVimage, &dstVimage, 0,  1, 0);
							else
								err = vImageConvert_FTo16U( &srcVimage, &dstVimage, 0,  1, 0);
							
							spacingY = spacingX;
							height = newHeight;
							
							data = squaredata;
							
							free( tempFloatSrc);
							free( tempFloatDst);
						}
					}
				}
			}
			
			#if __BIG_ENDIAN__
			if( bps == 16)
			{
				//Convert to little endian
				InverseShorts( (vector unsigned short*) data, height * width);
			}
			#endif
			
			int elemLength = height * width * spp * bps / 8;
			
			if( elemLength%2 != 0)
			{
				height--;
				elemLength = height * width * spp * bps / 8;
				
				if( elemLength%2 != 0) NSLog( @"***************** ODD element !!!!!!!!!!");
			}
			
			NSNumber *rows = [NSNumber numberWithInt: height];
			NSNumber *columns  = [NSNumber numberWithInt: width];
			
			NSMutableData *imageNSData = [NSMutableData dataWithBytes:data length: elemLength];
			NSString *vr;
			int highBit;
			int bitsAllocated;
			float numberBytes;
			
			switch( bps)
			{
				case 8:			
					highBit = 7;
					bitsAllocated = 8;
					numberBytes = 1;
				break;
				
				case 16:			
					highBit = 15;
					bitsAllocated = 16;
					numberBytes = 2;
				break;
				
				case 32:  // float support
					highBit = 31;
					bitsAllocated = 32;
					numberBytes = 4;
				break;
				
				default:
					NSLog(@"Unsupported bps: %d", bps);
					return nil;
				break;
			}
			
			NSString *photometricInterpretation = @"MONOCHROME2";
			if (spp == 3) photometricInterpretation = @"RGB";
			
			[dcmDst release];
			dcmDst = [[DCMObject secondaryCaptureObjectWithBitDepth: bps  samplesPerPixel:spp numberOfFrames:1] retain];
			
			if( charSet) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:charSet] forName:@"SpecificCharacterSet"];
			if( studyUID) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:studyUID] forName:@"StudyInstanceUID"];
			if( exportSeriesUID) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:exportSeriesUID] forName:@"SeriesInstanceUID"];
			if( exportSeriesDescription) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:exportSeriesDescription] forName:@"SeriesDescription"];
			
			if( patientName) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:patientName] forName:@"PatientsName"];
			if( patientID) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:patientID] forName:@"PatientID"];
			if( studyDescription) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:studyDescription] forName:@"StudyDescription"];
			if( seriesNumber) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:seriesNumber] forName:@"SeriesNumber"];
			if( studyID) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:studyID] forName:@"StudyID"];
			
			if( dcmObject)
			{
				if([dcmObject attributeValueWithName:@"PatientsSex"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"PatientsSex"]] forName:@"PatientsSex"];
				if([dcmObject attributeValueWithName:@"PatientsBirthDate"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"PatientsBirthDate"]] forName:@"PatientsBirthDate"];
				if([dcmObject attributeValueWithName:@"AccessionNumber"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"AccessionNumber"]] forName:@"AccessionNumber"];
				if([dcmObject attributeValueWithName:@"InstitutionName"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"InstitutionName"]] forName:@"InstitutionName"];
				if([dcmObject attributeValueWithName:@"InstitutionAddress"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"InstitutionAddress"]] forName:@"InstitutionAddress"];
				if([dcmObject attributeValueWithName:@"PerformingPhysiciansName"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"PerformingPhysiciansName"]] forName:@"PerformingPhysiciansName"];
				
				if([dcmObject attributeValueWithName:@"ReferringPhysiciansName"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"ReferringPhysiciansName"]] forName:@"ReferringPhysiciansName"];
				else [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: @""] forName:@"ReferringPhysiciansName"];
				
				if( modalityAsSource)
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject: [dcmObject attributeValueWithName:@"Modality"]] forName:@"Modality"];
			}
			else
			{
				[dcmDst setAttributeValues:[NSMutableArray arrayWithObject: @""] forName:@"ReferringPhysiciansName"];
			}
			
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:@"OsiriX"] forName:@"ManufacturersModelName"];
			
			if( studyDate) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:studyDate] forName:@"StudyDate"];
			if( studyTime) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:studyTime] forName:@"StudyTime"];
			if( seriesDate) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:seriesDate] forName:@"SeriesDate"];
			if( seriesTime) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:seriesTime] forName:@"SeriesTime"];
			if( acquisitionDate) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:acquisitionDate] forName:@"AcquisitionDate"];
			if( acquisitionTime) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:acquisitionTime] forName:@"AcquisitionTime"];
			if( contentDate) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:contentDate] forName:@"ContentDate"];
			if( contentTime) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:contentTime] forName:@"ContentTime"];
			
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:exportInstanceNumber++]] forName:@"InstanceNumber"];
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt: 1]] forName:@"AcquisitionNumber"];
			
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:rows] forName:@"Rows"];
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:columns] forName:@"Columns"];
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:spp]] forName:@"SamplesperPixel"];
			
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:photometricInterpretation] forName:@"PhotometricInterpretation"];
			
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithBool:isSigned]] forName:@"PixelRepresentation"];
			
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:highBit]] forName:@"HighBit"];
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:bitsAllocated]] forName:@"BitsAllocated"];
			[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:bitsAllocated]] forName:@"BitsStored"];
			
			if( spacingX != 0 && spacingY != 0)
			{
				[dcmDst setAttributeValues:[NSMutableArray arrayWithObjects:[NSNumber numberWithFloat:spacingY], [NSNumber numberWithFloat:spacingX], nil] forName:@"PixelSpacing"];
			}
			if( sliceThickness != 0) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithFloat:sliceThickness]] forName:@"SliceThickness"];
			if( orientation[ 0] != 0 || orientation[ 1] != 0 || orientation[ 2] != 0) [dcmDst setAttributeValues:[NSMutableArray arrayWithObjects:[NSNumber numberWithFloat:orientation[ 0]], [NSNumber numberWithFloat:orientation[ 1]], [NSNumber numberWithFloat:orientation[ 2]], [NSNumber numberWithFloat:orientation[ 3]], [NSNumber numberWithFloat:orientation[ 4]], [NSNumber numberWithFloat:orientation[ 5]], nil] forName:@"ImageOrientationPatient"];
			if( position[ 0] != 0 || position[ 1] != 0 || position[ 2] != 0) [dcmDst setAttributeValues:[NSMutableArray arrayWithObjects:[NSNumber numberWithFloat:position[ 0]], [NSNumber numberWithFloat:position[ 1]], [NSNumber numberWithFloat:position[ 2]], nil] forName:@"ImagePositionPatient"];
			if( slicePosition != 0) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithFloat:slicePosition]] forName:@"SliceLocation"];
			if( spp == 3) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithFloat:0]] forName:@"PlanarConfiguration"];
			
			if( bps == 32) // float support
			{
				vr = @"FL";
				
				[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt: 0]] forName:@"RescaleIntercept"];
				[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithFloat: 1]] forName:@"RescaleSlope"];
				
				if( [[dcmObject attributeValueWithName:@"Modality"] isEqualToString:@"CT"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: @"HU"] forName:@"RescaleType"];
				else [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: @"US"] forName:@"RescaleType"];
				
				if( ww != -1 && ww != -1)
				{
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:wl]] forName:@"WindowCenter"];
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:ww]] forName:@"WindowWidth"];
				}
			}
			else if( bps == 16)
			{
				vr = @"OW";
				
				if( isSigned == NO)
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt: offset]] forName:@"RescaleIntercept"];
				else
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt: 0]] forName:@"RescaleIntercept"];
				
				[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithFloat: slope]] forName:@"RescaleSlope"];
				
				if( [[dcmObject attributeValueWithName:@"Modality"] isEqualToString:@"CT"]) [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: @"HU"] forName:@"RescaleType"];
				else [dcmDst setAttributeValues:[NSMutableArray arrayWithObject: @"US"] forName:@"RescaleType"];
				
				if( ww != -1 && ww != -1)
				{
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:wl]] forName:@"WindowCenter"];
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithInt:ww]] forName:@"WindowWidth"];
				}
			}
			else
			{
				if( spp != 3)
				{
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithFloat:0]] forName:@"RescaleIntercept"];
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject:[NSNumber numberWithFloat:1]] forName:@"RescaleSlope"];
					[dcmDst setAttributeValues:[NSMutableArray arrayWithObject: @"US"] forName:@"RescaleType"];
				}
				
				vr = @"OB";
			}
			
			DCMTransferSyntax *ts;
			ts = [DCMTransferSyntax ExplicitVRLittleEndianTransferSyntax];
			
			DCMAttributeTag *tag = [DCMAttributeTag tagWithName:@"PixelData"];
			DCMPixelDataAttribute *attr = [[[DCMPixelDataAttribute alloc] initWithAttributeTag:tag 
											vr:vr 
											length:numberBytes
											data:nil 
											specificCharacterSet:nil
											transferSyntax:ts 
											dcmObject:dcmDst
											decodeData:NO] autorelease];
			[attr addFrame:imageNSData];
			[dcmDst setAttribute:attr];
			
			if (dcmExport)
				[dcmExport finalize: dcmDst withSourceObject: dcmObject];
			
			// Add to the current DB
			if( dstPath == nil)
			{
				dstPath = [[BrowserController currentBrowser] getNewFileDatabasePath: @"dcm"];
				[dcmDst writeToFile:dstPath withTransferSyntax:ts quality:DCMLosslessQuality atomically:YES];
			}
			else
				[dcmDst writeToFile:dstPath withTransferSyntax:ts quality:DCMLosslessQuality atomically:YES];
			
			if( squaredata)
				free( squaredata);
			squaredata = nil;
			
			return dstPath;
		}
		@catch (NSException *e)
		{
			NSLog( @"*********** WriteDCMFile failed : %@", e);
			return nil;
		}
	}
	else return nil;
	
	return nil;
}
@end