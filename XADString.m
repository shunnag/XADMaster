/*
 * XADString.m
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#import "XADString.h"

#import "../UniversalDetector/UniversalDetector.h"



NSString *XADASCIIStringEncodingName=@"US-ASCII";
NSString *XADUTF8StringEncodingName=@"UTF-8";

NSString *XADISOLatin1StringEncodingName=@"iso-8859-1";
NSString *XADISOLatin2StringEncodingName=@"iso-8859-2";
NSString *XADISOLatin3StringEncodingName=@"iso-8859-3";
NSString *XADISOLatin4StringEncodingName=@"iso-8859-4";
NSString *XADISOLatin5StringEncodingName=@"iso-8859-5";
NSString *XADISOLatin6StringEncodingName=@"iso-8859-6";
NSString *XADISOLatin7StringEncodingName=@"iso-8859-7";
NSString *XADISOLatin8StringEncodingName=@"iso-8859-8";
NSString *XADISOLatin9StringEncodingName=@"iso-8859-9";
NSString *XADISOLatin10StringEncodingName=@"iso-8859-10";
NSString *XADISOLatin11StringEncodingName=@"iso-8859-11";
NSString *XADISOLatin12StringEncodingName=@"iso-8859-12";
NSString *XADISOLatin13StringEncodingName=@"iso-8859-13";
NSString *XADISOLatin14StringEncodingName=@"iso-8859-14";
NSString *XADISOLatin15StringEncodingName=@"iso-8859-15";
NSString *XADISOLatin16StringEncodingName=@"iso-8859-16";

NSString *XADShiftJISStringEncodingName=@"Shift_JIS";

NSString *XADWindowsCP1250StringEncodingName=@"windows-1250";
NSString *XADWindowsCP1251StringEncodingName=@"windows-1251";
NSString *XADWindowsCP1252StringEncodingName=@"windows-1252";
NSString *XADWindowsCP1253StringEncodingName=@"windows-1253";
NSString *XADWindowsCP1254StringEncodingName=@"windows-1254";

NSString *XADMacOSRomanStringEncodingName=@"macintosh";
NSString *XADMacOSJapaneseStringEncodingName=@"x-mac-japanese";
NSString *XADMacOSTraditionalChineseStringEncodingName=@"x-mac-trad-chinese";
NSString *XADMacOSKoreanStringEncodingName=@"x-mac-korean";
NSString *XADMacOSArabicStringEncodingName=@"x-mac-arabic";
NSString *XADMacOSHebrewStringEncodingName=@"x-mac-hebrew";
NSString *XADMacOSGreekStringEncodingName=@"x-mac-greek";
NSString *XADMacOSCyrillicStringEncodingName=@"x-mac-cyrillic";
NSString *XADMacOSSimplifiedChineseStringEncodingName=@"x-mac-simp-chinese";
NSString *XADMacOSRomanianStringEncodingName=@"x-mac-romanian";
NSString *XADMacOSUkranianStringEncodingName=@"x-mac-ukrainian";
NSString *XADMacOSThaiStringEncodingName=@"x-mac-thai";
NSString *XADMacOSCentralEuropeanRomanStringEncodingName=@"x-mac-centraleurroman";
NSString *XADMacOSIcelandicStringEncodingName=@"x-mac-icelandic";
NSString *XADMacOSTurkishStringEncodingName=@"x-mac-turkish";
NSString *XADMacOSCroatianStringEncodingName=@"x-mac-croatian";

static BOOL IsDataASCII(NSData *data);
static BOOL IsDataConfidentlyUTF8(NSData *data); // [cooViewer]

@implementation XADString

+(XADString *)XADStringWithString:(NSString *)string
{
	return [[[self alloc] initWithString:string] autorelease];
}

+(XADString *)analyzedXADStringWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
{
	[stringsource analyzeData:bytedata];

	if(IsDataASCII(bytedata))
	{
		return [self decodedXADStringWithData:bytedata encodingName:XADASCIIStringEncodingName];
	}
	// [cooViewer] Even without an explicit UTF-8 flag, treat a name as UTF-8 when its
	// bytes are confidently UTF-8 (legacy zip lacking GP bit 11, GNU/ustar tar, LHA,
	// RAR3 8-bit names). This compensates for universalchardet's known weakness on short
	// CJK names without regressing legacy archives. The shared detector was already fed
	// above, so mixed-encoding archives are unaffected.
	else if(IsDataConfidentlyUTF8(bytedata))
	{
		return [self decodedXADStringWithData:bytedata encodingName:XADUTF8StringEncodingName];
	}
	else
	{
		return [[[self alloc] initWithData:bytedata source:stringsource] autorelease];
	}
}

+(XADString *)decodedXADStringWithData:(NSData *)bytedata encodingName:(NSString *)encoding
{
	NSString *string=[XADString stringForData:bytedata encodingName:encoding];
	return [[[self alloc] initWithString:string] autorelease];
}




+(NSString *)escapedStringForData:(NSData *)data encodingName:(NSString *)encoding
{
	NSString *decstr=[XADString stringForData:data encodingName:encoding];
	if(decstr) return decstr;

	// Fall back on escaped ASCII if the encoding was unusable.
	return [self escapedASCIIStringForBytes:[data bytes] length:[data length]];
}

+(NSString *)escapedStringForBytes:(const void *)bytes length:(size_t)length
encodingName:(NSString *)encoding
{
	NSString *decstr=[XADString stringForBytes:bytes length:length encodingName:encoding];
	if(decstr) return decstr;

	// Fall back on escaped ASCII if the encoding was unusable.
	return [self escapedASCIIStringForBytes:bytes length:length];
}

+(NSString *)escapedASCIIStringForBytes:(const void *)bytes length:(size_t)length
{
	// [cooViewer] Build the escaped string in one C buffer instead of an appendFormat:
	// per byte. This path runs for every name of an archive whose detected encoding
	// fails to decode (a mis-detected or corrupt name table), where the old per-byte
	// format-string parse was a ~100 ms cliff on a 2000-entry book. Each byte expands to
	// at most 3 chars ("%xx"); output is byte-for-byte identical (ASCII verbatim, high
	// bytes as lowercase %xx).
	static const char hex[]="0123456789abcdef";
	const uint8_t *byteptr=bytes;
	char *out=malloc(length*3+1);
	if(!out) return @"";
	size_t o=0;
	for(size_t i=0;i<length;i++)
	{
		uint8_t b=byteptr[i];
		// A NUL byte is dropped to match the original appendFormat:@"%c" behavior, where
		// a 0 argument appends nothing (embedded NUL in a name is pathological anyway).
		if(b==0) continue;
		if(b<0x80) out[o++]=b;
		else { out[o++]='%'; out[o++]=hex[b>>4]; out[o++]=hex[b&0xf]; }
	}
	NSString *result=[[[NSString alloc] initWithBytes:out length:o
	encoding:NSASCIIStringEncoding] autorelease];
	free(out);
	return result?result:@"";
}

+(NSData *)escapedASCIIDataForString:(NSString *)string
{
	// [cooViewer] One C buffer instead of a per-character appendBytes:/characterAtIndex:.
	// characterAtIndex: in a loop is O(n) per call on some string backings; pull the
	// UTF-16 units once. Each unit expands to at most 6 bytes ("%uXXXX"); output is
	// byte-for-byte identical to the original (ASCII verbatim, others as %uXXXX).
	NSUInteger length=[string length];
	unichar *units=malloc(length*sizeof(unichar));
	if(!units) return [NSData data];
	[string getCharacters:units range:NSMakeRange(0,length)];

	static const char hex[]="0123456789abcdef";
	uint8_t *out=malloc(length*6);
	if(!out) { free(units); return [NSData data]; }
	size_t o=0;
	for(NSUInteger i=0;i<length;i++)
	{
		unichar c=units[i];
		if(c<0x80) out[o++]=(uint8_t)c;
		else
		{
			out[o++]='%'; out[o++]='u';
			out[o++]=hex[(c>>12)&0xf]; out[o++]=hex[(c>>8)&0xf];
			out[o++]=hex[(c>>4)&0xf]; out[o++]=hex[c&0xf];
		}
	}
	NSData *result=[NSData dataWithBytes:out length:o];
	free(units); free(out);
	return result;
	// Do not use this because Cocotron doesn't support it.
	//return [string dataUsingEncoding:NSNonLossyASCIIStringEncoding];
}




-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
{
	if((self=[super init]))
	{
		data=[bytedata retain];
		string=nil;
		source=[stringsource retain];
	}
	return self;
}

-(id)initWithString:(NSString *)knownstring
{
	if((self=[super init]))
	{
		string=[knownstring retain];
		data=nil;
		source=nil;
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[string release];
	[source release];
	[super dealloc];
}



-(BOOL)canDecodeWithEncodingName:(NSString *)encoding
{
	if(string) return YES;
	return [XADString canDecodeData:data encodingName:encoding];
}

-(NSString *)string
{
	return [self stringWithEncodingName:[source encodingName]];
}

-(NSString *)stringWithEncodingName:(NSString *)encoding
{
	if(string) return string;
	if(!data) return nil;
	return [XADString escapedStringForData:data encodingName:encoding];
}

-(NSData *)data
{
	if(data) return data;
	return [XADString escapedASCIIDataForString:string];
}



-(BOOL)encodingIsKnown
{
	if(!source) return YES;
	if([source hasFixedEncoding]) return YES;
	return NO;
}

-(NSString *)encodingName
{
	if(!source) return XADUTF8StringEncodingName; // TODO: what should this really return?
	return [source encodingName];
}

-(float)confidence
{
	if(!source) return 1;
	return [source confidence];
}



-(XADStringSource *)source { return source; }



-(BOOL)hasASCIIPrefix:(NSString *)asciiprefix
{
	if(string) return [string hasPrefix:asciiprefix];
	else
	{
		NSInteger length=[asciiprefix length];
		if([data length]<length) return NO;

		const uint8_t *bytes=[data bytes];
		for(NSInteger i=0;i<length;i++) if(bytes[i]!=[asciiprefix characterAtIndex:i]) return NO;

		return YES;
	}
}

-(XADString *)XADStringByStrippingASCIIPrefixOfLength:(int)length
{
	if(string)
	{
		return [[[XADString alloc]
		initWithString:[string substringFromIndex:length]]
		autorelease];
	}
	else
	{
		return [[[XADString alloc]
		initWithData:[data subdataWithRange:
		NSMakeRange(length,[data length]-length)]
		source:source] autorelease];
	}
}



-(BOOL)isEqual:(id)other
{
	if([other isKindOfClass:[NSString class]]) return [[self string] isEqual:other];
	else if([other isKindOfClass:[self class]])
	{
		XADString *xadstr=(XADString *)other;

		if(string&&xadstr->string) return [string isEqual:xadstr->string];
		else if(data&&xadstr->data&&source==xadstr->source) return [data isEqual:xadstr->data];
		else return NO;
	}
	else return NO;
}

-(NSUInteger)hash
{
	if(string) return [string hash];
	else return [data hash];
}



-(NSString *)description
{
	// TODO: more info?
	NSString *actualstring=[self string];
	if(!actualstring) return @"(nil)";
	return actualstring;
}

-(id)copyWithZone:(NSZone *)zone
{
	if(string) return [[XADString allocWithZone:zone] initWithString:string];
	else return [[XADString allocWithZone:zone] initWithData:data source:source];
}


#ifdef __APPLE__
-(BOOL)canDecodeWithEncoding:(NSStringEncoding)encoding
{
	return [self canDecodeWithEncodingName:[XADString encodingNameForEncoding:encoding]];
}

-(NSString *)stringWithEncoding:(NSStringEncoding)encoding
{
	return [self stringWithEncodingName:[XADString encodingNameForEncoding:encoding]];
}

-(NSStringEncoding)encoding
{
	if(!source) return NSUTF8StringEncoding; // TODO: what should this really return?
	else return [source encoding];
}
#endif

@end



@implementation XADStringSource

-(id)init
{
	if((self=[super init]))
	{
		detector=[UniversalDetector new]; // can return nil if UniversalDetector is not found
		fixedencodingname=nil;
		mac=NO;
		hasanalyzeddata=NO;
	}
	return self;
}

-(void)dealloc
{
	[detector release];
	[fixedencodingname release];
	[super dealloc];
}

-(void)analyzeData:(NSData *)data
{
	hasanalyzeddata=YES;
	[detector analyzeData:data];
}

-(BOOL)hasAnalyzedData { return hasanalyzeddata; }

-(NSString *)encodingName
{
	if(fixedencodingname) return fixedencodingname;
	if(!detector) return XADWindowsCP1252StringEncodingName;

	NSString *encoding=[detector MIMECharset];
	if(!encoding) encoding=XADWindowsCP1252StringEncodingName;

	// Kludge to use Mac encodings instead of the similar Windows encodings for Mac archives
	// TODO: improve
	if(mac)
	{
		static NSDictionary *macalternatives=nil;
		if(!macalternatives) macalternatives=[[NSDictionary alloc] initWithObjectsAndKeys:
			XADMacOSRomanStringEncodingName,[XADASCIIStringEncodingName lowercaseString],
			XADMacOSRomanStringEncodingName,[XADWindowsCP1252StringEncodingName lowercaseString],
			XADMacOSJapaneseStringEncodingName,[XADShiftJISStringEncodingName lowercaseString],
		nil];

		NSString *macalternative=[macalternatives objectForKey:[encoding lowercaseString]];
		if(macalternative) return macalternative;
	}

	return encoding;
}

-(float)confidence
{
	if(fixedencodingname) return 1;
	if(!detector) return 0;
	if(![detector MIMECharset]) return 0;
	return [detector confidence];
}

-(UniversalDetector *)detector
{
	return detector;
}

-(void)setFixedEncodingName:(NSString *)encoding
{
	[fixedencodingname autorelease];
	fixedencodingname=[encoding retain];
}

-(BOOL)hasFixedEncoding
{
	return fixedencodingname!=nil;
}

-(void)setPrefersMacEncodings:(BOOL)prefermac
{
	mac=prefermac;
}



#ifdef __APPLE__
-(NSStringEncoding)encoding
{
	NSString *encodingname=[self encodingName];
	if(!encodingname) return 0;

	return [XADString encodingForEncodingName:encodingname];
}

-(void)setFixedEncoding:(NSStringEncoding)encoding
{
	if(!encoding) [self setFixedEncodingName:nil];
	else [self setFixedEncodingName:[XADString encodingNameForEncoding:encoding]];
}
#endif

@end




static BOOL IsDataASCII(NSData *data)
{
	const char *bytes=[data bytes];
	NSInteger length=[data length];
	for(NSInteger i=0;i<length;i++) if(bytes[i]&0x80) return NO;
	return YES;
}

// [cooViewer] "Confident UTF-8" test used by +analyzedXADStringWithData:source: as a
// pre-detector fast path. Two conditions:
//  (1) The whole buffer is STRICTLY valid UTF-8 (RFC 3629 / Unicode Standard Table 3-7):
//      overlong forms, surrogates (U+D800-DFFF), code points above U+10FFFF, truncated
//      sequences and stray continuation bytes are all rejected. Strictness matters — a
//      lenient decoder (e.g. CFString) would accept many legacy CP932/EUC/GBK/Big5 names.
//  (2) The buffer contains at least one 3- or 4-byte sequence (an E-/F-lead). Every CJK,
//      kana and Hangul character encodes as a 3-byte UTF-8 sequence (emoji as 4-byte), so
//      real UTF-8 CJK filenames always satisfy this. A legacy 2-byte CJK pair, when it
//      coincidentally forms valid UTF-8, almost always yields 2-byte (C-lead) sequences,
//      so requiring a 3-byte sequence collapses the legacy false-positive rate to
//      near-zero. Measured over ~18k realistic legacy CJK names (SJIS/EUC-JP/GBK/Big5/
//      CP949): condition (1) alone misfires ~0.5-1.7%; adding (2) drops it to <0.03%,
//      while UTF-8 CJK recall stays 100%. (A pure-Latin-Extended UTF-8 name of only
//      2-byte sequences is left to the detector, which is not the CJK case this targets.)
static BOOL IsDataConfidentlyUTF8(NSData *data)
{
	const unsigned char *b=[data bytes];
	NSInteger len=[data length];
	NSInteger i=0;
	BOOL sawLongSequence=NO; // saw a 3- or 4-byte sequence (condition 2)
	while(i<len)
	{
		unsigned char c=b[i];
		if(c<0x80) { i++; } // ASCII
		else if(c>=0xC2&&c<=0xDF) // 2-byte (0xC0/0xC1 would be overlong)
		{
			if(i+1>=len||b[i+1]<0x80||b[i+1]>0xBF) return NO;
			i+=2;
		}
		else if(c==0xE0) // 3-byte, second byte 0xA0-0xBF excludes overlong
		{
			if(i+2>=len||b[i+1]<0xA0||b[i+1]>0xBF||b[i+2]<0x80||b[i+2]>0xBF) return NO;
			sawLongSequence=YES; i+=3;
		}
		else if((c>=0xE1&&c<=0xEC)||c==0xEE||c==0xEF) // 3-byte
		{
			if(i+2>=len||b[i+1]<0x80||b[i+1]>0xBF||b[i+2]<0x80||b[i+2]>0xBF) return NO;
			sawLongSequence=YES; i+=3;
		}
		else if(c==0xED) // 3-byte, second byte 0x80-0x9F excludes surrogates
		{
			if(i+2>=len||b[i+1]<0x80||b[i+1]>0x9F||b[i+2]<0x80||b[i+2]>0xBF) return NO;
			sawLongSequence=YES; i+=3;
		}
		else if(c==0xF0) // 4-byte, second byte 0x90-0xBF excludes overlong
		{
			if(i+3>=len||b[i+1]<0x90||b[i+1]>0xBF||b[i+2]<0x80||b[i+2]>0xBF||b[i+3]<0x80||b[i+3]>0xBF) return NO;
			sawLongSequence=YES; i+=4;
		}
		else if(c>=0xF1&&c<=0xF3) // 4-byte
		{
			if(i+3>=len||b[i+1]<0x80||b[i+1]>0xBF||b[i+2]<0x80||b[i+2]>0xBF||b[i+3]<0x80||b[i+3]>0xBF) return NO;
			sawLongSequence=YES; i+=4;
		}
		else if(c==0xF4) // 4-byte, second byte 0x80-0x8F keeps it <= U+10FFFF
		{
			if(i+3>=len||b[i+1]<0x80||b[i+1]>0x8F||b[i+2]<0x80||b[i+2]>0xBF||b[i+3]<0x80||b[i+3]>0xBF) return NO;
			sawLongSequence=YES; i+=4;
		}
		else return NO; // 0x80-0xC1 (stray continuation / overlong lead) or 0xF5-0xFF
	}
	return sawLongSequence;
}
