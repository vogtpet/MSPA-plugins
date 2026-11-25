Third-party components in the MSPA binaries
===========================================

The MSPA executables bundled with this plugin are built and distributed by
the European Commission's Joint Research Centre (JRC). They link the
following libraries statically, so no separate library files are shipped:

* libdeflate (MIT) - https://github.com/ebiggers/libdeflate
  License text: MIT.txt

* Lerc (Apache-2.0) - https://github.com/Esri/lerc
  License text: Apache-2.0.txt

The binaries also link the system C library (and, on macOS, the system zlib)
dynamically; those are part of the operating system.

The complete list of third-party components of MSPA is maintained in
MSPAstandalone: https://github.com/vogtpet/MSPAstandalone#third-party-components
