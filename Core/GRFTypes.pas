unit GRFTypes;

interface
const
	GRF_SUCCESS = 0;
	GRF_FILELOCKED = 1;
	GRF_INVALID = 2;
	GRF_UNKNOWN_CRYPT = 3;
	GRF_UNIMPLEMENT_VERSION = 4;
	GRF_CORRUPTED = 5;
	GRF_STAKEOVERFLOW = 6;
	GRF_STAKERANGEOUT = 7;
	GRF_NOTMODIFIED = 8;
	GRF_FILENOTFOUND = 9;
	GRF_FILECHANGED = 10;
	GRF_EXTRACTFAIL = 11;

	//From libgrf
	// Known flags for GRF/GPF files
	GRFFILE_FLAG_FILE =$01;	// File entry
				// GrfFile::type flag to specify that
				// entry is a file when set (and
				// directory when not set)
	GRFFILE_FLAG_MIXCRYPT=$02; //< Encrypted
				 // GrfFile::type flag to specify that the file
				 // uses mixed crypto, explained in grfcrypt.h.
	GRFFILE_FLAG_0x14_DES=$04;// Encrypted
				// GrfFile::type flag to specify that only the
				// first 0x14 blocks are encrypted.
				// Explained in grfcrypt.h
implementation

end.
