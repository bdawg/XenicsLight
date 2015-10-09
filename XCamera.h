/** \file XCamera.h */
#ifndef _XENICS_XCAMERA_GEN2_H_
#   define _XENICS_XCAMERA_GEN2_H_

    /**/////////////////////////////////////////////////////////////////////////////
    //// XenicsAPI - Interface definition
    ////////////////////////////////////////////////////////////////////////////////
    //// Implementation by Jonathan Cloots, commissioned by Xenics N.V.
    //////////////////////////////////////////////////////////////////////////////*/

#ifdef _WIN32
#   ifndef CALLCV
#       define CALLCV       __stdcall                       ///< Compatibility with VB6
#       define CALLCVCB     __cdecl
#   else
#       pragma message ("Warning: building using custom calling convention.")
#   endif

#   ifdef _USRDLL
#       define IMPEXP   __declspec(dllexport)               ///< Attributes for C++ exports
#       define IMPEXPC  __declspec(dllexport) CALLCV        ///< Attributes for C   exports
#   else
#       define IMPEXP   __declspec(dllimport)               ///< Attributes for C++ exports
#       define IMPEXPC  __declspec(dllimport) CALLCV        ///< Attributes for C   exports
#   endif
#else
#   define CALLCV
#   define CALLCVCB
#   define IMPEXP
#   define IMPEXPC
#endif

#ifdef __cplusplus
    extern "C" {
#endif

    /**! \public
		These are the error codes used throughout the API */
    typedef enum  
    {
        I_OK                    = 0,                /**< Success                                                                         */
        I_DIRTY                 = 1,                /**< Internal                                                                        */
        E_BUG                   = 10000,            /**< Generic                                                                         */
        E_NOINIT                = 10001,            /**< Camera was not successfully initialised                                         */
        E_LOGICLOADFAILED       = 10002,            /**< Invalid logic file                                                              */
        E_INTERFACE_ERROR       = 10003,            /**< Command interface failure                                                       */
        E_OUT_OF_RANGE          = 10004,            /**< Provided value is incapable of being produced by the hardware                   */
        E_NOT_SUPPORTED         = 10005,            /**< Functionality not supported by this camera                                      */
        E_NOT_FOUND             = 10006,            /**< File/Data not found.                                                            */
        E_FILTER_DONE           = 10007,            /**< Filter has finished processing, and will be removed                             */
        E_NO_FRAME              = 10008,            /**< A frame was requested by calling GetFrame, but none was available               */
        E_SAVE_ERROR            = 10009,            /**< Couldn't save to file                                                           */
        E_MISMATCHED            = 10010,            /**< Buffer size mismatch                                                            */
        E_BUSY                  = 10011,            /**< The API can not read a temperature because the camera is busy                   */
        E_INVALID_HANDLE        = 10012,            /**< An unknown handle was passed to the C API                                       */
        E_TIMEOUT               = 10013,            /**< Operation timed out                                                             */
        E_FRAMEGRABBER          = 10014,            /**< Frame grabber error                                                             */
        E_NO_CONVERSION         = 10015,            /**< GetFrame could not convert the image data to the requested format               */
        E_FILTER_SKIP_FRAME     = 10016,            /**< Filter indicates the frame should be skipped.                                   */
        E_WRONG_VERSION         = 10017,            /**< Version mismatch                                                                */
        E_PACKET_ERROR          = 10018,            /**< The requested frame cannot be provided because at leat one packet has been lost */
        E_WRONG_FORMAT          = 10019,            /**< The emissivity map you tried to set should be a 16 bit grayscale png            */
        E_WRONG_SIZE            = 10020,            /**< The emissivity map you tried to set has the wrong dimensions (w,h)              */
        E_CAPSTOP               = 10021,            /**< Internal                                                                        */
        E_RFU
    } ErrorCodes;

    /** The different colour mappings available for greyscale data sources, these affect display and saving colour coded images to disk */
    typedef enum 
    {
        ColourMode_8            = 0,                    /**< [8-bit ] Intensity only                                                               */
        ColourMode_16           = 1,                    /**< Alias                                                                                 */
        ColourMode_Profile      = 2,                    /**< [8-bit ] Uses a colour profile bitmap. See LoadColourProfile                          */
        ColourMode_Invert       = 256                   /**< [8-bit ] Use an inverted colour profile bitmap ex: (ColourMode_8 | ColourMode_Invert) */
    } ColourMode;

    /** The different destinations the XC_Blit function supports */
    typedef enum 
    {
        Window          = 0,                        /**< HWND - Window handle, blit directly to a window's client device context                                */
        DeviceContext                               /**< HDC  - Blit to a specified device context (memory dc, paint dc, the dc of an image control in c#...)   */
    } BlitType;

    /** Frametypes available for on the fly conversion, please note that this is . */
    typedef enum
    {
        /// Sensor pixel types
        FT_NATIVE       = 0,                        /**< The native frametype of this camera (can be FT_8..,FT_16..,FT32.. check GetFrameType()  */
        FT_8_BPP_GRAY   = 1,                        /**< 8bpp                                                                                    */
        FT_16_BPP_GRAY  = 2,                        /**< 16bpp (default for most of our cameras)                                            */
        FT_32_BPP_GRAY  = 3,                        /**< 32bpp                                                                              */
        /// Conversion types (FT_16_BPP_GRAY -> ...)
        FT_32_BPP_RGBA  = 4,                        /**< 32bpp colour RGBA      [B,G,R,A] Available for output conversion in XC_GetFrame    */
        FT_32_BPP_RGB   = 5,                        /**< 32bpp colour RGB       [B,G,R]   Available for output conversion in XC_GetFrame    */
        FT_32_BPP_BGRA  = 6,                        /**< 32bpp colour BGRA      [R,G,B,A]                                                   */
        FT_32_BPP_BGR   = 7                         /**< 32bpp colour BGR       [R,G,B]                                                     */
    } FrameType;

    /** Basic types */
    typedef int            XCHANDLE;                /**< handle to the camera                   */
    typedef unsigned long  ErrCode;                 /**< error code                             */
    typedef unsigned long  FilterID;                /**< used filter ID                         */

    typedef unsigned long  dword;                   /**< 4 bytes (32 bits)                      */
    typedef unsigned short word;                    /**< 2 bytes (16 bits)                      */
    typedef unsigned char  byte;                    /**< 1 byte  ( 8 bits)                      */
    typedef unsigned char  boole;                   /**< 1 byte  ( 8 bits)                      */
    typedef void *         voidp;                   /**< void pointer type                      */

    /** Image filter messages */
    typedef enum 
    {
        XMsgInit                = 0,          /**< [Api->Filter Event] Called when the filter is being installed  ( (!) calling thread context)         */
        XMsgClose               = 1,          /**< [Api->Filter Event] Called when the filter is being removed    ( (!) calling thread context)         */
        XMsgFrame               = 2,          /**< [Api->Filter Event] Called after every frame grab              ( (!) grabbing thread context)        */
        XMsgGetName             = 3,          /**< [App->Filter Event] Retrieve filter name: the filter should copy a friendly string to msgparm        */
        XMsgGetValue            = 4,          /**< [Obsolete]                                                                                           */
        XMsgSave                = 5,          /**< [Obsolete]                                                                                           */
        XMsgGetStatus           = 6,          /**< [Api->Filter Event] Retrieves a general purpose status message from the image filter                 */
        XMsgUpdateViewPort      = 7,          /**< [Api->Filter Event] Instructs an image correction filter to update it's view port
                                                                       This message is sent to a filter upon changing the window of interest, or when
                                                                       flipping image horizontally or vertically                                        */
        XMsgCanProceed          = 8,          /**< Used by image filters in in interactive mode to indicate acceptable image conditions                 */
        XMsgGetInfo             = 9,          /**< [Internal]          Used to query filter 'registers'                                                 */
        XMsgSelect              = 10,         /**< [Obsolete]                                                                                           */
        XMsgProcessedFrame      = 11,         /**< [Api->Filter Event] Sent after other filters have done their processing. Do not modify the frame data 
                                                                       in response to this event.                                                       */
        XMsgTimeout             = 13,         /**< [Api->Filter Event] A camera timeout event was generated                                             */
        XMsgIsBusy              = 16,         /**< [Thermography]      Is the temperature filter recalculating - Used to check if the thermal filter is 
                                                                       still updating it's linearisation tables                                         */
        XMsgSetTROI             = 17,         /**< [Imaging/Thermo]    Set the adu/temperature span in percent, \sa XMsgSetTROIParms                    */
        XMsgLoad                = 18,         /**< [Obsolete]                                                                                           */
        XMsgUnload              = 19,         /**< [Obsolete]                                                                                           */
        XMsgADUToTemp           = 12,         /**< [Thermography]      Convert an ADU value to a temperature (\sa XFltADUToTemperature)                 */
        XMsgGetEN               = 14,         /**< [Thermography]      Get temperature correction parameters                                            */
        XMsgSetEN               = 15,         /**< [Thermography]      Set temperature correction parameters                                            */
        XMsgTempToADU           = 20,         /**< [Thermography]      Convert a temperature to an ADU value (\sa XFltTemperatureToADU)                 */
        XMsgGetTValue           = 21,         /**< [Thermography]      Retrieve an emissivity corrected value from a coordinate                         */
        XMsgSerialise           = 100,        /**< [App->Filter event] Serialise internal parameter state (write xml structure) \sa XFltSetParameter    */
        XMsgDeserialise         = 101,        /**< [App->Filter event] Deserialise parameter state (read xml structure) \sa XFltSetParameter            */
        XMsgGetPriority         = 102,        /**< [Filter Management] Write the current filter priority to the long * provided in v_pMsgParm           */
        XMsgSetFilterState      = 104,        /**< [Filter Management] Enable or disable an image filter temporarily by sending 0/1 in v_pMsgParm       */
        XMsgIsSerialiseDirty    = 105,        /**< [Internal]                                                                                           */
        XMsgStoreHandle         = 106,        /**< [Internal]          Start tracking the module handle for plugin image filters                        */
        XMsgUpdateTint          = 107,        /**< [Api->Filter event] Integration time change notification                                             */
        XMsgLinADUToTemp        = 109,        /**< [Thermography]      Convert a Linearized ADU value to a temperature (\sa XFltADUToTemperatureLin)    */
        XMsgLinTempToADU        = 110,        /**< [Thermography]      Convert a temperature to a Linearized ADU value (\sa XFltTemperatureToADULin)    */
        XMsgUpdateSpan          = 111,        /**< [Api->Filter event] Span change notification                                                         */
        XMsgUpdatePalette       = 112,        /**< [Api->Filter event] Colour profile change notification                                               */
        XMsgDrawOverlay         = 200,        /**< [Api->Filter event] Draw the RGBA frame overlay, v_pMsgParm is the pointer to the RGBA data 
                                                                       structure                                                                        */
        XMsgLineariseOutput     = 201,        /**< [Thermography]      When specifying a v_pMsgParm that is non zero, starts linearising adu output     */
        XMsgSetEmiMap           = 202,        /**< [Thermography]      Streams the main emissivity map to the thermal filter (16 bit png, 65535 = 1.0)  */
        XMsgSetEmiMapUser       = 203,        /**< [Thermography]      Stream a user emissivity map to the thermal filter (16 bit png, 65535 = 1.0, 
                                                                       0 values are replaced by the emissivity in the main map)                         */
        XMsgGetEmiMap           = 204,        /**< [Thermography]      Stream out the combined emissivity map                                           */
        XMsgClrEmiMap           = 205,        /**< [Thermography]      Clear emissivity map                                                             */
        XMsgClrEmiMapUser       = 206,        /**< [Thermography]      Clear emissivity map (user)                                                      */
        XMsgPushRange           = 207,        /**< [Thermography]      Push a new linearization range to the thermal filter                             */
        XMsgThmFilterState      = 208,        /**< [Thermography]      Filter event indicating thermal filter queue/removal                             */
        XMsgThmAdjustSet        = 209,        /**< [Thermography]      Set global offset & gain adu adjustement (pre-thermal conversion)                */
        XMsgThmAdjustGet        = 210,        /**< [Thermography]      \sa XMsgTempAdjustmentParms                                                      */
        
        XMsgLog                 = 211,              /**< [Plugin->Api]       Fire a log event to the end user application\n                                                       
                                                                             Target filter id: 0xffffffff                                                                         */
        XMsgGetDeltaT           = 212,              /**< [Internal]                                                                                                               */
        XMsgGetTintRange        = 213,              /**< [Plugin->Api]       Request the exposure time range                                                                      
                                                                             Target filter id: 0xffffffff                                                                         */
        XMsgUser                = 24200       /**< If you develop your own image filter plugins, please use this constant to offset
                                                   your messages */
    } XFilterMessage;

    /** Image filter prototype                                              */
    /** @param v_pCamera    - pointer to camera object                      */
    /** @param v_pUserParm  - user parameter as specified in AddImageFilter */
    /** @param tMsg         - as per XFilterMessage                         */
    /** @param v_pMsgParm   - as per MsgImageFilter                         */
    typedef ErrCode (CALLCVCB *XImageFilter)(void *v_pCamera, void *v_pUserParm, XFilterMessage tMsg, void *v_pMsgParm);

    /** Status messages (see also XStatus) */
    typedef enum  {
        XSLoadLogic     = 1,    /**< Passed when loading the camera's main logic file                           */
        XSLoadVideoLogic= 2,    /**< Passed when loading the camera's video output firmware                     */
        XSDataStorage   = 3,    /**< Passed when accessing persistent data on the camera                        */
        XSCorrection    = 4,    /**< Passed when uploading correction data to the camera                        */
        XSSelfStart     = 5,    /**< Passed when a self starting camera is starting (instead of XSLoadLogic)    */
        XSMessage       = 6,    /**< String event                                                               
                                 **  This status message is used to relay critical errors, and events originating
                                 **  from within the API.
                                 **  Cam|PropLimit|property=number - A filter notifies you your user interface should limit the value of 'property' to 'number'
                                 **  Cam|ThermalRangeUpdate        - The thermography filter uses this to notify you of a span update.
                                 **  Cam|InterfaceUpdate           - Internal, do not handle, returning E_BUG here causes the API to stop unpacking 'abcd.package'.packages to %appdata%/xenics/interface
                                 **
                                 **
                                 **/
        XSLoadGrabber   = 7     /**< Passed when loading the framegrabber                                       */
    } XStatusMessage;

    /** Status callback prototype                   */
    /** @param v_pUserParm  - user parameter        */
    /** @param iMsg         - as per XStatusMessage */
    /** @param ulP          - progress              */
    /** @param ulT          - total                 */
    /** @param pMsgParm       msg parameter         */
    /** Notes: */
    /** When iMsg == XSMessage a string pointer is passed in the integers ulP and ulT, the lower part of the address is stored in ulP, the 
        higher in ulT (64-bit port) */
    typedef ErrCode (CALLCVCB *XStatus)(void *v_pUserParm, int iMsg, unsigned long ulP, unsigned long ulT);

    /** GetFrame flags */
    typedef enum  
    {
        XGF_Blocking    = 1,    /**< Blocking mode, wait for a frame forever, and do not return immediately with the return codes E_NO_FRAME / I_OK                             */
        XGF_NoConversion= 2,    /**< Prevents internal conversion to 8 bit, specifying this flag reduces computation time, but prevents SaveData from working                   */
        XGF_FetchPFF    = 4,    /**< Retrieve the per frame footer with frame timing information (* use XCamera::GetFrameFooterLength to determine the increase in framesize)   */
        XGF_RFU_1       = 8,
        XGF_RFU_2       = 16,
        XGF_RFU_3       = 32
    } XGetFrameFlags;

    /** SaveData flags */
    typedef enum  
    {
        XSD_Force16             = 1,    /**< Forces 16 bit output independent of the current ColourMode setting (only possible for TIFF's and PNG's)    */
        XSD_Force8              = 2,    /**< Forces 8 bit output independent of the current  ColourMode                                                 */
        XSD_AlignLeft           = 4,    /**< Left aligns 16 bit output (XSD_Force16|XSD_AlignLeft)                                                      */
        XSD_SaveThermalInfo     = 8,    /**< Save thermal conversion structure (only available when saving 16 bit png)                                  */
        XSD_RFU_0               = 16,   /**< Reserved                                                                                                   */
        XSD_RFU_1               = 32,
        XSD_RFU_2               = 64,
        XSD_RFU_3               = 128
    } XSaveDataFlags;

    /** SaveSettings flags */
    typedef enum  
    {
        XSS_SaveReadables     = 1,    /**< Saves read properties to the setting file as well. */
        XSS_SaveGrabberProps  = 2,    /**< */
        XSS_SS_RFU_2          = 4,    /**< */
        XSS_SS_RFU_3          = 8     /**< */
    } XSaveSettingsFlags;

    /** LoadSettings flags */
    typedef enum  
    {
        XSS_IgnoreNAIS        = 1,    /**< Ignore properties which do not affect the image. */
        XSS_LS_RFU_1          = 2,    /**< */
        XSS_LS_RFU_2          = 4,    /**< */
        XSS_LS_RFU_3          = 8     /**< */
    } XLoadSettingsFlags;

    /** LoadCalibration flags */
    typedef enum  
    {
        XLC_StartSoftwareCorrection     = 1,    /**< Starts the software correction filter after unpacking the calibration data */
        XLC_RFU_1                       = 2,
        XLC_RFU_2                       = 4,
        XLC_RFU_3                       = 8
    } XLoadCalibrationFlags;

    /** Property types */
    typedef enum
    { 
        XType_None              = 0x00000000    , /**< */

        XType_Base_Mask         = 0x000000ff    , /**< Type mask */
        XType_Attr_Mask         = 0xffffff00    , /**< Attribute mask                */
        XType_Base_Number       = 0x00000001    , /**< A number (floating)           */
        XType_Base_Enum         = 0x00000002    , /**< An enumerated type (a choice) */
        XType_Base_Bool         = 0x00000004    , /**< Boolean (true/false/1/0)      */
        XType_Base_Blob         = 0x00000008    , /**< Binary large object           */
        XType_Base_String       = 0x00000010    , /**< String                        */
        XType_Base_Action       = 0x00000020    , /**< Action (button) */
        XType_Base_Rfu1         = 0x00000040    , /**< Rfu */
        XType_Base_Rfu2         = 0x00000080    , /**< Rfu */

        XType_Base_MinMax       = 0x00002000    , /**< The property accepts the strings 'min' and 'max' to set the best achievable extremities. */
        XType_Base_ReadOnce     = 0x00001000    , /**< Property needs to be read at startup only */
        XType_Base_NoPersist    = 0x00000800    , /**< Property shouldn't be persisted (saved & restored) */
        XType_Base_NAI          = 0x00000400    , /**< Property does not affect image intensity level ('Not Affecting Image') */
        XType_Base_RW           = 0x00000300    , /**< Write and read back */
        XType_Base_Writeable    = 0x00000200    , /**< Writable properties have this set in their high byte */
        XType_Base_Readable     = 0x00000100    , /**< Readable properties have this set in their high byte     */

        XType_Number            = 0x00000201    , /**< Write only number                */
        XType_Enum              = 0x00000202    , /**< Write only enum                  */
        XType_Bool              = 0x00000204    , /**< Write only boolean               */
        XType_Blob              = 0x00000208    , /**< Write only binary large object   */
        XType_String            = 0x00000210    , /**< Write only string                */
        XType_Action            = 0x00000220    , /**< Action (button)                                                                          */

        XType_RO_Number         = 0x00000101    , /**< Read only number                 */
        XType_RO_Enum           = 0x00000102    , /**< Read only enum                   */
        XType_RO_Bool           = 0x00000104    , /**< Read only boolean                */
        XType_RO_Blob           = 0x00000108    , /**< Read only binary large object    */
        XType_RO_String         = 0x00000110    , /**< Read only string                 */


        XType_RW_Number         = 0x00000301    , /**< R/W number                       */
        XType_RW_Enum           = 0x00000302    , /**< R/W enum                         */
        XType_RW_Bool           = 0x00000304    , /**< R/W boolean                      */
        XType_RW_Blob           = 0x00000308    , /**< R/W binary large object          */
        XType_RW_String         = 0x00000310      /**< R/W string                       */
    } XPropType;

    /** Property types */
    typedef enum
    { 
        XDir_FilterData         = 0x0000    , /**< Filter data (%appdata%/xenics/data/sessionnumber/                */
        XDir_ScriptRoot         = 0x0001    , /**< Script root (%appdata%/xenics/interface/pidnumber/               */
        XDir_Calibrations       = 0x0002    , /**< Calibration folder (%programfiles%/xeneth/calibrations/)         */
        XDir_InstallDir         = 0x0003    , /**< Installation folder (%commonfiles/xenics/runtime/)               */
        XDir_Plugins            = 0x0004    , /**< Plugin folder (%commonfiles/xenics/runtime/plugins/)             */
        XDir_CachePath          = 0x0005    , /**< Cache folder (%appdata%/xenics/cache/)                           */
        XDir_SdkResources       = 0x0006    , /**< SDK resource folder (%commonfiles%/xenics/runtime/resources/)    */
        XDir_Xeneth             = 0x0007    , /**< Xeneth installation directory                                    */
    } XDirectories;

    /* Structures */
#pragma pack(push, 1)

    /** Per frame footer */
    typedef struct  
    {
        unsigned short len;     /**< Structure length                                                   */
        unsigned short ver;     /**< AA00                                                               */

        long long      soc;     /**< Time of Start Capture (us since start of epoch)                    */
        long long      tft;     /**< Time of reception (us since start of epoch)                        */
        dword          tfc;     /**< Framecounter                                                       */
        dword          fltref;  /**< Reference for attaching messages/frame (described in XFooters.h)   */
        dword          hfl;     /**< Hardware footer length                                             */
    } XPFF;                     /**< \sa GetFrameFooterLength                                           */

#pragma pack(pop)

#ifdef __cplusplus
    }
#endif

#ifdef __cplusplus

    //////////////////////////////////////////////////////////////////////////////////////
    /// Xeneth SDK - Main interface to Xenics N.V. cameras
    ////////////////////////////////////////////////////////////////////////////////////
    class XCamera  
    {
        protected:
            XCamera();

        public:
            //////////////////////////////////////////////////////////////////////////////////////////
            /// Opening the camera
            //////////////////////////////////////////////////////////////////////////////////////////

            /// Enumerates all available devices. Device names are separated by a pipe '|' symbol.
            /// @param pList zero terminated string which will receive the device list
            /// @param iMaxLen allocated memory available for the device list
            /// @return A device list containing 'connectionurl'|'description' .. 
            static void IMPEXP GetDeviceList(char *pList, int iMaxLen);

            /// Creates a camera object.
            /// @param pCameraName  The camera connection url as returned by GetDeviceList (!)
            ///                         Special cameras: 
            ///                         cam://default - first camera detected
            ///                         cam://select  - start xeneth (if installed) to select a camera
            ///                         soft://0      - virtual camera (for application development without a camera)
            ///                         Options:
            ///                         cam://x?fg=none                    - Start API command & control mode (no framegrabbing)
            ///                         cam://x?fg=XFrameGrabberNative     - Given the choice between using a cameralink grabber and the native protocol (ether/usb..) use the native one.
            ///
            /// @param pCallBack    Progress callback function ( of type XStatus )
            /// @param pUser        User parameter for said callback function
            /// @return A pointer to the created XCamera object, or NULL in case of an allocation error.
            static XCamera IMPEXP *Create(const char *pCameraName = "cam://default", XStatus pCallBack = 0, void *pUser = 0);
             
            /// The destructor closes the connection, so calling delete( ) on the created camera object releases your connection.
            virtual ~XCamera();

            /// Checks if the camera was found and properly initialised/connected.
            /// If the camera has experienced an internal error, this function will return false. 
            /// If the camera can not be found (dissapeared between enumeration and connection), this function will return false. 
            /// @return bool True if properly initialised, false if not.
            virtual bool        IsInitialised   ()=0;

            //////////////////////////////////////////////////////////////////////////////////////////
            /// Frame dimensions
            //////////////////////////////////////////////////////////////////////////////////////////

            /// The current viewport width in number of pixels. 
            /// @return dword Width in number of pixels. 
            virtual dword       GetWidth        ()=0;

            /// The current viewport height in number of pixels. 
            /// @return dword Height in number of pixels.
            virtual dword       GetHeight       ()=0;

            /// The maximum viewport width in number of pixels. 
            /// @return dword Width in pixels. 
            virtual dword       GetMaxWidth     ()=0;

            /// The maximum viewport height in number of pixels. 
            /// @return dword Height in pixels. 
            virtual dword       GetMaxHeight    ()=0;

            //////////////////////////////////////////////////////////////////////////////////////////
            // Capture control
            //////////////////////////////////////////////////////////////////////////////////////////

            /// Is the interface board capturing data. 
            /// @return bool True if capturing data, false if not.  
            virtual bool        IsCapturing     ()=0;

            /// Enables the internal frame grabbing thread. 
            /// This starts the camera in free running mode.
            ///
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode      StartCapture   ()=0;

            /// Disables the internal frame grabbing thread. 
            /// 
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode      StopCapture    ()=0;

            //////////////////////////////////////////////////////////////////////////////////////////
            // Data filters
            //////////////////////////////////////////////////////////////////////////////////////////

            // Note that these callbacks are executed in a different thread than the caller.

            /// Registers an image filter callback
            /// @param flt ImageFilter definition
            /// @param parm 
            /// @return FilterID
            virtual FilterID    AddImageFilter      (XImageFilter flt, void *parm)=0;

            /// Sends a message to an image filter. 
            /// @param fid Filter ID. 
            /// @param msg Message to the filter. @sa {XFilterMessage}
            /// @param msgparm Parameters to pass to the image filter in question.
            /// @return An error code 
            virtual ErrCode     MsgImageFilter      (FilterID fid, XFilterMessage msg, void *msgparm)=0;

            /// Removes an image filter. 
            /// @param fid Filter ID. 
            /// @return none
            virtual void        RemImageFilter      (FilterID fid)=0;

            /// Set the filter's position in the filter stack.
            /// @param fid  Filter ID. 
            /// @param prio Indicates the new position of the fid. 
            ///             When set to 0 the filter is positioned at the top of the stack.
            ///             When given a negative number the filter is positioned in front of the filter with id prio.
            
            /// @return none
            virtual void        PriImageFilter      (FilterID fid, int prio)=0;

            /// Checks if a filter has completed it's run cycle.
            /// @param  fid     Filter ID. 
            /// @return bool    True or false
            virtual bool        IsFilterRunning     (FilterID fid)=0;
            
            //////////////////////////////////////////////////////////////////////////////////////////
            // Drawing
            //////////////////////////////////////////////////////////////////////////////////////////

            /// Blits an image to a native window handle (HWND/GtkWidget/...). 
            /// @param where    Handle to a window(HWND) or Device context(HDC). 
            /// @param x        X coordinate of destination, upper-left corner. 
            /// @param y        Y coordinate of destination upper-left corner. 
            /// @param w        Width of destination rectangle. 
            /// @param h        Height of destination rectangle. 
            /// @param type     Specifies wether or not where is a window or a dc @sa BlitType
            /// @return none. 
            virtual void        Blit                (void *where, int x, int y, int w, int h, BlitType type)=0;

            /// Sets the blitter's colour mode. 
            /// @param mode Enumerated type of colours. GreyScale (0), PseudoColour (1) or FullColour(2). 
            /// @return none. 
            virtual void        SetColourMode       (ColourMode mode)=0;

            /// Gets the blitter's colour mode. 
            /// @return mode Enumerated type of colours. GreyScale (0), PseudoColour (1) or FullColour(2). 
            virtual ColourMode  GetColourMode       ()=0;

            /// Loads a colour profile bitmap from disk. (To be used in conjunction with SetColourMode 's <b>Profile</b> mode)
            /// Colour profile bitmaps should be 1x256 pixels (Bigger is ok, but only (0,0->255) will be utilised).
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     LoadColourProfile   (const char *p_cFileName)=0;

            /// Retreives an index from the current palette
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPaletteNdx       (unsigned int ndx, byte &red, byte &green, byte &blue)=0;
            
            //////////////////////////////////////////////////////////////////////////////////////////
            // Data acquisition
            //////////////////////////////////////////////////////////////////////////////////////////

            /// Gets a pointer to the internal frame buffer. 
            /// This function may *only* be used inside an image filter
            /// The amount of bits used in the data is rounded up to the next whole byte (14 bit = 16 bit frame data, 25 bit = 32 bit frame data)
            /// @return Pointer to the frame buffer.
            virtual void *      GetFrame        ()=0;

            /// Returns the native frame type of this camera. @sa FrameType
            virtual FrameType   GetFrameType    ()=0;

            /// Returns the frame buffer size in bytes.
            /// @return Number of bytes.
            virtual dword       GetFrameSize    ()=0;

            /// Returns actual bits in use
            virtual byte        GetBitSize      ()=0;

            /// Returns the maximum pixel value
            virtual dword       GetMaxValue     ()=0;
            
            /// Copies the entire frame into user supplied memory. 
            /// The image or frame buffer will be copied over a size in bytes. 
            /// @param type     @sa FrameType - Supported conversion types: FT_32_BPP_RGBA/FT_32_BPP_RGB(24bpp colour triplets) or FT_NATIVE (no conversion)
            /// @param ulFlags  @sa XGetFrameFlags
            /// @param buffer   User supplied memory where the the image or frame will be copied. 
            /// @param size     Size in bytes of the user supplied buffer. 
            /// @return An error code if more bytes are specified than the frame size in bytes (see GetFrameSizeInBytes). @sa ErrorCodes
            virtual ErrCode     GetFrame        (FrameType type, unsigned long ulFlags, void * buffer, unsigned int size)=0;

            /// Gets the number of frames since StartCapture. 
            /// @return Frame index. 
            virtual dword       GetFrameCount   ()=0;

            /// Gets current frame rate. 
            /// @return Frame rate. 
            virtual double      GetFrameRate    ()=0;

            /// Saves 8 bit image data to a bitmap
            /// Saves the 16 bit image data when saving Portable Network Graphics (PNG) or Tagged Image File Format (TIFF) if FullColour is set, or when using XSD_Force16
            /// (For other formats (which do not support 16bit image channels the most significant bits are stored in the red component the others in the green component)
            /// @param ulFlags      @sa XSaveDataFlags
            /// @param p_cFileName  Filename where the data is to be stored.
            /// @return E_SAVE_ERROR if this function fails on I/O. @sa ErrorCodes
            virtual ErrCode     SaveData        (const char *p_cFileName, unsigned long ulFlags=0)=0;

            //////////////////////////////////////////////////////////////////////////////////////////
            // Configuration management
            //////////////////////////////////////////////////////////////////////////////////////////

            /// Loads camera settings from a configuration file.
            /// @param  p_cFileName Filename to an .XCF file.
            /// @param  ulFlags *New in v2.1* @sa XLoadSettingsFlags
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     LoadSettings        (const char *p_cFileName, unsigned long ulFlags=0)=0;

            /// Saves camera settings to a configuration file.
            /// @param  p_cFileName Filename to an .XCF file.
            /// @param  ulFlags *New in v2.1* @sa XSaveSettingsFlags
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     SaveSettings        (const char *p_cFileName, unsigned long ulFlags=0)=0;

            /// Loads sensor calibration data, and optionally starts the correction filter too.
            /// @param ulFlags      @sa XLoadCalibrationFlags
            /// @param p_cFileName  Filename to the .XCA file you wish to load.
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     LoadCalibration     (const char *p_cFileName, unsigned long ulFlags=0)=0;

            /// Fetches the location of Xeneth directories @sa XDirectories
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPath             (int iPath, char *pPath, int iMaxLen)=0;

            //////////////////////////////////////////////////////////////////////////////////////////
            // Property management
            //////////////////////////////////////////////////////////////////////////////////////////

            /// Retrieves the number of properties available on the currently connected device.
            /// @return The number of properties available on the currently connected device.
            virtual int         GetPropertyCount    ()=0;

            /// Retrieves the name of a property by its index
            /// @param iIndex       Legal values are 0 to GetPropertyCount() - 1
            /// @param pPropName    Destination string pointer that will receive the name
            /// @param iMaxLen      Amount of space reserved at pPropName
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPropertyName     (int iIndex, char *pPropName, int iMaxLen)=0;


            /// Retrieves the boundaries of a property
            /// For an enumerated type this is a list of possible values, for numeric types it returns "lowvalue>highvalue".
            /// @param pPrp     The property name
            /// @param pRange   Destination pointer that will receive the range
            /// @param iMaxLen  Reserved space in pRange
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPropertyRange    (const char *pPrp, char   *pRange   , int     iMaxLen   )=0;
            virtual ErrCode     GetPropertyRangeL   (const char *pPrp, long   *pLow     , long   *pHigh     )=0;    ///<Convenience function to extra higher & lower mark of numeric properties
            virtual ErrCode     GetPropertyRangeF   (const char *pPrp, double *pLow     , double *pHigh     )=0;    ///<Convenience function to extra higher & lower mark of numeric properties

            /// Retrieves the type of a property
            /// @param pPrp         The property name (for example: "IntegrationTime", or it's categorized alternative "Camera/General/Integration time")
            /// @param pPropType    The base property type plus it's attributes (readeable / writeable) @sa XPropType
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPropertyType     (const char *pPrp, XPropType *pPropType)=0;

            /// Retrieves where this property is located in the property hierarchy (notice the tree like placement in xeneth, this determines that placement)
            /// @param pPrp         The property name.
            /// @param pCategory    Category, serialized tree representation. (seperated by slashes)
            /// @param iMaxLen      Space reserved at pCategory.
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPropertyCategory (const char *pPrp, char *pCategory  , int iMaxLen )=0;

            /// Retrieve units supported by this property, default unit comes first
            /// @param pPrp The property name
            /// @param pUnit Destination for a comma separated list of supported units
            /// @param iMaxLen Maximum length of destination string.
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPropertyUnit     (const char *pPrp, char *pUnit      , int iMaxLen )=0;

            /// Sets the value of a named property
            /// @param pPrp     The property name (for example: "IntegrationTime", or it's categorized alternative "Camera/General/Integration time")
            /// @param pValue   The value to set the property to
            /// @param pUnit    RFU
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     SetPropertyValue    (const char *pPrp, const char *pValue       , const char *pUnit = ((const char*)0))=0;
            virtual ErrCode     SetPropertyValueL   (const char *pPrp, long lValue              , const char *pUnit = ((const char*)0))=0;  ///< Available for easy access
            virtual ErrCode     SetPropertyValueF   (const char *pPrp, double dValue            , const char *pUnit = ((const char*)0))=0;  ///< Available for easy access
            virtual ErrCode     SetPropertyBlob     (const char *pPrp, const char *pValue       , unsigned int len)=0;                      ///< Available for setting large binary objects

            /// Fetches the value of a named property
            /// For non camera readable properties this retreives the value last set, or the default.
            /// @param pPrp     The property name (for example: "TSensorNTC", or it's categorized alternative "Camera/Temperatures/Sensor/NTC Temperature")
            /// @param pValue   A pointer that will receive the value.
            /// @param iMaxLen  The number of bytes reserved in the destination pointer pValue
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     GetPropertyValue    (const char *pPrp, char *pValue     , int iMaxLen)=0;
            virtual ErrCode     GetPropertyValueL   (const char *pPrp, long *pValue     )=0;                                                ///< Available for easy access
            virtual ErrCode     GetPropertyValueF   (const char *pPrp, double *pValue   )=0;                                                ///< Available for easy access
            virtual ErrCode     GetPropertyBlob     (const char *pPrp, char *pValue     , unsigned int len)=0;                              ///< Available for getting large binary objects, use GetPropertyValueL to determine how many bytes to allocate, or overestimate the len field.

            /// Calling this function with a value of true causes properties to be cached until the next call of this function with a value of false.
            /// This is a nestable operation using a reference count.
            /// @return ErrCode @sa ErrorCodes
            virtual ErrCode     QueueProperties     (bool tf)=0;

            /// Returns the length of the XPFF structure as compiled into the API, plus any hardware frame footer. 
            /// (Certainly never use sizeof(XPFF) to determine the length!)
            /// @return XPFF structure length in bytes.
            virtual dword       GetFrameFooterLength()=0;
    };
#endif /* __cplusplus */

#ifdef __cplusplus
    extern "C" 
    {
#endif
        ///////////////////////////////////////////////////////////////////////////////////
        //	C Functions Definition
        ///////////////////////////////////////////////////////////////////////////////////
        /// @defgroup	c_api	General C Functions
        ///
        ///	@{
        ///////////////////////////////////////////////////////////////////////////////////
        XCHANDLE    IMPEXPC XC_OpenCamera                   (const char *pCameraName, XStatus pCallBack, void *pUser);    ///< @sa XCamera::Create
        void        IMPEXPC XC_CloseCamera                  (XCHANDLE hnd);                                                                         ///< @sa XCamera::~XCamera
        void        IMPEXPC XC_GetDeviceList                (char *pList, int iMaxLen);                                                             ///< @sa XCamera::GetDeviceList
    
        voidp       IMPEXPC XC_HandleToCamera               (XCHANDLE hHandle);                                                                     ///< Converts a C style handle to an XCamera instance pointer
        XCHANDLE    IMPEXPC XC_CameraToHandle               (voidp cam);                                                                            ///< Converts an XCamera instance pointer to a C style handle (For use in image filter callbacks)
        int         IMPEXPC XC_ErrorToString                (ErrCode e, char *dst, int len);                                                        ///< Converts an error code to a string, returns how many bytes were copied.

        boole       IMPEXPC XC_IsInitialised                (XCHANDLE h);                                                                           ///< @sa XCamera::IsInitialised                 
        dword       IMPEXPC XC_GetWidth                     (XCHANDLE h);                                                                           ///< @sa XCamera::GetWidth                      
        dword       IMPEXPC XC_GetHeight                    (XCHANDLE h);                                                                           ///< @sa XCamera::GetHeight                     
        dword       IMPEXPC XC_GetMaxWidth                  (XCHANDLE h);                                                                           ///< @sa XCamera::GetMaxWidth                   
        dword       IMPEXPC XC_GetMaxHeight                 (XCHANDLE h);                                                                           ///< @sa XCamera::GetMaxHeight                  
        boole       IMPEXPC XC_IsCapturing                  (XCHANDLE h);                                                                           ///< @sa XCamera::IsCapturing                   
        ErrCode     IMPEXPC XC_StartCapture                 (XCHANDLE h);                                                                           ///< @sa XCamera::StartCapture                  
        ErrCode     IMPEXPC XC_StopCapture                  (XCHANDLE h);                                                                           ///< @sa XCamera::StopCapture                   
        FilterID    IMPEXPC XC_AddImageFilter               (XCHANDLE h,XImageFilter flt, void *parm);                                              ///< @sa XCamera::AddImageFilter                
        ErrCode     IMPEXPC XC_MsgImageFilter               (XCHANDLE h,FilterID fid, XFilterMessage msg, void *msgparm);                           ///< @sa XCamera::MsgImageFilter                
        void        IMPEXPC XC_RemImageFilter               (XCHANDLE h,FilterID fid);                                                              ///< @sa XCamera::RemImageFilter                
        void        IMPEXPC XC_PriImageFilter               (XCHANDLE h,FilterID fid, int prio);                                                    ///< @sa XCamera::PriImageFilter                
        boole       IMPEXPC XC_IsFilterRunning              (XCHANDLE h,FilterID fid);                                                              ///< @sa XCamera::IsFilterRunning               
        void        IMPEXPC XC_Blit                         (XCHANDLE h,void *w, int x, int y, int width, int height, BlitType type);               ///< @sa XCamera::Blit                          
        void        IMPEXPC XC_SetColourMode                (XCHANDLE h,ColourMode mode);                                                           ///< @sa XCamera::SetColourMode             
        ColourMode  IMPEXPC XC_GetColourMode                (XCHANDLE h);                                                                           ///< @sa XCamera::GetColourMode             
        ErrCode     IMPEXPC XC_LoadColourProfile            (XCHANDLE h,const char *p_cFileName);                                                   ///< @sa XCamera::LoadColourProfile         
        voidp       IMPEXPC XC_GetFilterFrame               (XCHANDLE h);                                                                           ///< @sa XCamera::GetFrame()
        FrameType   IMPEXPC XC_GetFrameType                 (XCHANDLE h);                                                                           ///< @sa XCamera::GetFrameType                  
        dword       IMPEXPC XC_GetFrameSize                 (XCHANDLE h);                                                                           ///< @sa XCamera::GetFrameSize                  
        byte        IMPEXPC XC_GetBitSize                   (XCHANDLE h);                                                                           ///< @sa XCamera::GetBitSize                    
        dword       IMPEXPC XC_GetMaxValue                  (XCHANDLE h);                                                                           ///< @sa XCamera::GetMaxValue                   
        ErrCode     IMPEXPC XC_GetFrame                     (XCHANDLE h,FrameType type, unsigned long ulFlags, void * buffer, unsigned int size);   ///< @sa XCamera::GetFrame                      
        dword       IMPEXPC XC_GetFrameCount                (XCHANDLE h);                                                                           ///< @sa XCamera::GetFrameCount                 
        double      IMPEXPC XC_GetFrameRate                 (XCHANDLE h);                                                                           ///< @sa XCamera::GetFrameRate                  
        ErrCode     IMPEXPC XC_SaveData                     (XCHANDLE h, const char *p_cFileName, unsigned long ulFlags);                           ///< @sa XCamera::SaveData                      
        ErrCode     IMPEXPC XC_LoadSettings                 (XCHANDLE h, const char *p_cFileName);                                                  ///< @sa XCamera::LoadSettings                  
        ErrCode     IMPEXPC XC_LoadCalibration              (XCHANDLE h, const char *p_cFileName, unsigned long ulFlags);                           ///< @sa XCamera::LoadCalibration               
        ErrCode     IMPEXPC XC_SaveSettings                 (XCHANDLE h, const char *p_cFileName);                                                  ///< @sa XCamera::SaveSettings                  
        ErrCode     IMPEXPC XC_GetPath                      (XCHANDLE h, int iPath, char *pPath, int iMaxLen);                                      ///< @sa XCamera::GetPath                       
        int         IMPEXPC XC_GetPropertyCount             (XCHANDLE h);                                                                           ///< @sa XCamera::GetPropertyCount              
        ErrCode     IMPEXPC XC_GetPropertyName              (XCHANDLE h,int iIndex, char *pPropName, int iMaxLen);                                  ///< @sa XCamera::GetPropertyName               
        ErrCode     IMPEXPC XC_GetPropertyRange             (XCHANDLE h,const char *pPrp, char   *pRange            , int     iMaxLen   );          ///< @sa XCamera::GetPropertyRange              
        ErrCode     IMPEXPC XC_GetPropertyRangeL            (XCHANDLE h,const char *pPrp, long   *pLow              , long   *pHigh     );          ///< @sa XCamera::GetPropertyRangeL         
        ErrCode     IMPEXPC XC_GetPropertyRangeF            (XCHANDLE h,const char *pPrp, double *pLow              , double *pHigh     );          ///< @sa XCamera::GetPropertyRangeF         
        ErrCode     IMPEXPC XC_GetPropertyType              (XCHANDLE h,const char *pPrp, XPropType *pPropType);                                    ///< @sa XCamera::GetPropertyType               
        ErrCode     IMPEXPC XC_GetPropertyCategory          (XCHANDLE h,const char *pPrp, char *pCategory           , int iMaxLen );                ///< @sa XCamera::GetPropertyCategory           
        ErrCode     IMPEXPC XC_GetPropertyUnit              (XCHANDLE h,const char *pPrp, char *pUnit               , int iMaxLen );                ///< @sa XCamera::GetPropertyUnit               
        ErrCode     IMPEXPC XC_SetPropertyValue             (XCHANDLE h,const char *pPrp, const char *pValue        , const char *pUnit);           ///< @sa XCamera::SetPropertyValue              
        ErrCode     IMPEXPC XC_SetPropertyValueL            (XCHANDLE h,const char *pPrp, long lValue               , const char *pUnit);           ///< @sa XCamera::SetPropertyValueL         
        ErrCode     IMPEXPC XC_SetPropertyValueF            (XCHANDLE h,const char *pPrp, double dValue             , const char *pUnit);           ///< @sa XCamera::SetPropertyValueF         
        ErrCode     IMPEXPC XC_SetPropertyBlob              (XCHANDLE h,const char *pPrp, const char *pValue        , unsigned int len);            ///< @sa XCamera::SetPropertyBlob               
        ErrCode     IMPEXPC XC_GetPropertyValue             (XCHANDLE h,const char *pPrp, char *pValue              , int iMaxLen);                 ///< @sa XCamera::GetPropertyValue              
        ErrCode     IMPEXPC XC_GetPropertyValueL            (XCHANDLE h,const char *pPrp, long *pValue      );                                      ///< @sa XCamera::GetPropertyValueL         
        ErrCode     IMPEXPC XC_GetPropertyValueF            (XCHANDLE h,const char *pPrp, double *pValue    );                                      ///< @sa XCamera::GetPropertyValueF
        ErrCode     IMPEXPC XC_GetPropertyBlob              (XCHANDLE h,const char *pPrp, char *pValue      , unsigned int len);                    ///< @sa XCamera::GetPropertyBlob
        ErrCode     IMPEXPC XC_QueueProperties              (XCHANDLE h,bool tf);                                                                   ///< @sa XCamera::QueueProperties
        dword       IMPEXPC XC_GetFrameFooterLength         (XCHANDLE h);                                                                           ///< @sa XCamera::GetFrameFooterLength

        ///////////////////////////////////////////////////////////////////////////////////
        /// @}	
        ///////////////////////////////////////////////////////////////////////////////////

#ifdef __cplusplus
    }
#endif

#endif
