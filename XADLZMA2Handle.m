/*
 * XADLZMA2Handle.m
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

#import "XADLZMA2Handle.h"
#import "XADException.h"

static void *Alloc(ISzAllocPtr p,size_t size) { return malloc(size); }
static void Free(ISzAllocPtr p,void *address) { return free(address); }
static ISzAlloc allocator={Alloc,Free};

@implementation XADLZMA2Handle

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	if(self=[super initWithParentHandle:handle length:length])
	{
		startoffs=[parent offsetInFile];
		seekback=NO;

		Lzma2Dec_Construct(&lzma);
		if([propertydata length]>=1)
		if(Lzma2Dec_Allocate(&lzma,((uint8_t *)[propertydata bytes])[0],&allocator)==SZ_OK)
		{
			return self;
		}
	}

	[self release];
	return nil;
}

-(void)dealloc
{
	Lzma2Dec_Free(&lzma,&allocator);
	free(resetoutputs);
	free(resetpackeds);

	[super dealloc];

}

-(void)setSeekBackAtEOF:(BOOL)seekateof { seekback=seekateof; }

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	Lzma2Dec_Init(&lzma);
	bufbytes=bufoffs=0;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int total=0;

	while(total<num)
	{
		size_t destlen=num-total;
		size_t srclen=bufbytes-bufoffs;
		ELzmaStatus status;

		int res=Lzma2Dec_DecodeToBuf(&lzma,buffer+total,&destlen,inbuffer+bufoffs,&srclen,LZMA_FINISH_ANY,&status);

		total+=destlen;
		bufoffs+=srclen;

		if(res!=SZ_OK) [XADException raiseDecrunchException];
		if(status==LZMA_STATUS_NEEDS_MORE_INPUT)
		{
			bufbytes=[parent readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			if(!bufbytes) [parent _raiseEOF];
			bufoffs=0;
		}
		else if(status==LZMA_STATUS_FINISHED_WITH_MARK)
		{
			if(seekback) [parent skipBytes:-bufbytes+bufoffs];
			[self endStream];
			break;
		}
	}

	return total;
}

// [cooViewer] Walk the LZMA2 chunk headers once and record every dict-reset point.
// A dict-reset chunk boundary is byte-for-byte a valid LZMA2 stream start, so decoding
// can restart there with a fresh Lzma2Dec_Init. Reads only headers (skips packed data)
// via the parent handle; any malformed/short header abandons the index (leaving only the
// implicit reset at offset 0), so a corrupt or unindexable stream behaves exactly as
// before. Built lazily on the first backward seek; the parent position is disturbed but
// the caller always re-inits the decoder afterwards.
#define LZMA2_MAX_RESETS 4096
-(void)buildResetIndexIfNeeded
{
	if(indexbuilt) return;
	indexbuilt=YES;  // 一度きり(失敗しても再試行しない)

	off_t capacity=16;
	off_t *outs=malloc(capacity*sizeof(off_t));
	off_t *packs=malloc(capacity*sizeof(off_t));
	if(!outs||!packs) { free(outs); free(packs); return; }
	int count=0;

	@try
	{
		[parent seekToFileOffset:startoffs];
		off_t packedpos=0,outputpos=0;
		for(;;)
		{
			off_t chunkstart=packedpos;
			uint8_t control;
			if([parent readAtMost:1 toBuffer:&control]!=1) break;
			packedpos++;
			if(control==0x00) break;  // stream end

			BOOL isreset=NO;
			off_t unpacked,packed;
			if(control==0x01||control==0x02)
			{
				uint8_t hdr[2];
				if([parent readAtMost:2 toBuffer:hdr]!=2) { count=0; break; }
				packedpos+=2;
				unpacked=packed=((hdr[0]<<8)|hdr[1])+1;
				isreset=(control==0x01);
			}
			else if(control>=0x80)
			{
				uint8_t hdr[4];
				if([parent readAtMost:4 toBuffer:hdr]!=4) { count=0; break; }
				packedpos+=4;
				unpacked=((off_t)(control&0x1f)<<16)+((hdr[0]<<8)|hdr[1])+1;
				packed=((hdr[2]<<8)|hdr[3])+1;
				int resetmode=(control>>5)&3;
				if(resetmode>=2)
				{
					uint8_t props;
					if([parent readAtMost:1 toBuffer:&props]!=1) { count=0; break; }
					packedpos++;
				}
				isreset=(resetmode==3);
			}
			else { count=0; break; }  // 未知の control = 索引破棄

			if(isreset)
			{
				if(count>=LZMA2_MAX_RESETS) break;  // 病的多数 = 打ち切り(既存分は有効)
				if(count>=capacity)
				{
					capacity*=2;
					off_t *no=realloc(outs,capacity*sizeof(off_t));
					off_t *np=realloc(packs,capacity*sizeof(off_t));
					if(!no||!np) { free(no?no:outs); free(np?np:packs); return; }
					outs=no; packs=np;
				}
				outs[count]=outputpos;
				packs[count]=chunkstart;
				count++;
			}
			[parent skipBytes:packed];
			packedpos+=packed;
			outputpos+=unpacked;
		}
	}
	@catch(id e) { count=0; }

	if(count<=1) { free(outs); free(packs); return; }  // 再開点が実質無い
	resetoutputs=outs;
	resetpackeds=packs;
	numresets=count;
}

-(void)seekToFileOffset:(off_t)offset
{
	if(![self _prepareStreamSeekTo:offset]) return;

	if(offset<streampos)
	{
		[self buildResetIndexIfNeeded];
		// 目標以下で最大の reset 点を二分探索
		int best=-1;
		if(numresets>0)
		{
			int lo=0,hi=numresets-1;
			while(lo<=hi)
			{
				int mid=(lo+hi)/2;
				if(resetoutputs[mid]<=offset) { best=mid; lo=mid+1; }
				else hi=mid-1;
			}
		}
		if(best>=1)  // best==0 は先頭からの再開=従来経路と同じなので使わない
		{
			// dict-reset 点からの再開。0x01 非圧縮リセット点は「直後の LZMA チャンクが
			// props を持つ」ことに依存する(7-Zip は必ず持たせるが LZMA2 仕様上の保証は
			// ない)。想定外の第三者ストリームで再開が壊れた場合に備え、失敗したら
			// 先頭からの再展開(従来動作)へ静かに戻す — 以前復号できた入力を壊さない
			@try
			{
				[parent seekToFileOffset:startoffs+resetpackeds[best]];
				Lzma2Dec_Init(&lzma);
				bufbytes=bufoffs=0;
				streampos=resetoutputs[best];
				endofstream=NO;
				[self readAndDiscardBytes:offset-streampos];
				return;
			}
			@catch(id e)
			{
				streampos=0;
				endofstream=NO;
				[self resetStream];
				[self readAndDiscardBytes:offset];
				return;
			}
		}
	}

	[super seekToFileOffset:offset];
}

@end

