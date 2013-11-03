#!/usr/bin/env ruby
#
# The MIDIator driver to interact with OSX's CoreMIDI.  Taken more or less
# directly from Practical Ruby Projects.
#
# == Authors
#
# * Topher Cyll
# * Ben Bleything <ben@bleything.net>
#
# == Copyright
#
# Copyright (c) 2008 Topher Cyll
#
# This code released under the terms of the MIT license.
#

require 'dl/import'
require 'ffi'
require 'midiator'
require 'midiator/driver'
require 'midiator/driver_registry'

class MIDIator::Driver::CoreMIDI < MIDIator::Driver # :nodoc:
  ##########################################################################
  ### S Y S T E M   I N T E R F A C E
  ##########################################################################
  module C # :nodoc:
    extend DL::Importer
    dlload '/System/Library/Frameworks/CoreMIDI.framework/Versions/Current/CoreMIDI'

    extern "int MIDIClientCreate( void*, void*, void*, void* )"
    extern "int MIDIClientDispose( void* )"
    extern "int MIDIGetNumberOfDestinations()"
    extern "void* MIDIGetDestination( int )"
    extern "int MIDIOutputPortCreate( void*, void*, void* )"
    extern "void* MIDIPacketListInit( void* )"
    extern "void* MIDIPacketListAdd( void*, int, void*, int, int, void* )"
    extern "int MIDISend( void*, void*, void* )"
  end

  module CF # :nodoc:
   extend DL::Importer
    dlload '/System/Library/Frameworks/CoreFoundation.framework/Versions/Current/CoreFoundation'

    extern "void* CFStringCreateWithCString( void*, char*, int )"

  #  extend FFI::Library
   # ffi_lib '/System/Library/Frameworks/CoreFoundation.framework/Versions/Current/CoreFoundation'
    # attach_function :CFStringCreateWithCString, [:pointer,:string,:int], :void

  end

  ##########################################################################
  ### D R I V E R   A P I
  ##########################################################################

  def open
    client_name = CF.CFStringCreateWithCString( nil, "MIDIator", 0 )
    @client = DL::CPtr.new(DL::malloc(DL::TYPE_VOID) )
    C.MIDIClientCreate( client_name, nil, nil, @client.ref )

    port_name = CF.CFStringCreateWithCString( nil, "Output", 0 )
    @outport = DL::CPtr.new( DL::malloc(DL::TYPE_VOID) )
    C.MIDIOutputPortCreate( @client, port_name, @outport.ref )

    number_of_destinations = C.MIDIGetNumberOfDestinations
    raise MIDIator::NoMIDIDestinations if number_of_destinations < 1
    @destination = C.MIDIGetDestination( 0 )
  end

  def close
    C.MIDIClientDispose( @client )
  end

  def message( *args )
    format = "C" * args.size
    bytes = FFI::MemoryPointer.from_string(args.pack( format ))
    packet_list = DL.malloc( 256 )
    packet_ptr = C.MIDIPacketListInit( packet_list )

    # Pass in two 32-bit 0s for the 64 bit time
    packet_ptr = C.MIDIPacketListAdd( packet_list, 256, packet_ptr, 0, args.size, bytes )

    C.MIDISend( @outport, @destination, packet_list )
  end
end
