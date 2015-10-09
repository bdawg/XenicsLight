% xenethSDK is a matlab wrapper class for the Xenics Xeneth Windows API
% 
% INSTALLATION. To install place xenethSDK on matlab path. The XenethAPI must be
% installed on the system to use.
% 
% Requires xeneth_shrlib.m(mfile that replaces header) required for Matlab
% Compiler) and associated thunk files for 64bit to be in MATLAB path or or
% you must adjust the loadlibary call to target C header.
% 
% NOTE: Matlab's loadlibary require the DLL header to be standard C.
%       The XC_OpenCamera header def does not conform. The default values
%       must be removed. i.e. line 659 should be:
% XCHANDLE IMPEXPC XC_OpenCamera(const char *pCameraName, XStatus pCallBack, void *pUser);
% 
% API install links.
% http://www.xenics.com\files\Support\Xeneth2.4-API.zip
% http://www.xenics.com\files\Support\Xeneth2.4-API64.zip
% 
% Xeneth Control install links.
% http://www.xenics.com\files\Support\Xeneth2.4-Advanced.zip
% http://www.xenics.com\files\Support\Xeneth2.4-Advanced64.zip
% 
% http://www.xenics.com\files\Support\Xeneth2.4Manual.zip
% 
% Documentation. Reference information is available through "doc xenethSDK"
% 
% Copyright(C) Chris Betters 2012-2014

% ############################################################
% CHANGE LOG
% ############################################################
% 
% 21/01/2012
% Version 1.0
% 
% 23/01/2012
% Added documentation: use 'doc xenethSDK'
% Currently requres property to be updated manually to match camera. List is
% not exsaustive. Use list_all_prop method to see all avaliable property for a
% connected camera.
% 
% 24/02/2014
% Added cleaner delete method. Seems to stop crashes when restarting a
% program using the class.
% Added interface to start and stop capture.
% 
% ############################################################

% % mallab class to interface with Xeneth SDK
% list of property still needs to be expanded...
classdef xenethSDK < handleAllHidden
    properties(Access = private)
        cam_ptr;
        device = 'cam://0';
        shrlib = 'camlib';
        
        getlh; % listener handles
        setlh;
        
        % property categories
        % property can read/write
        property = {'IntegrationTime','Fan','ADCVREF','ADCVIN','Gain','LowGain','SETTLE','ImageSource','BitShift','TemperatureOffset'};
        
        % getpropsRO ae read only property of camera. Attempting to set
        % them will not call SetPropertyValue.
        GetPropsRO = {'Temperature','CAM_SER','CAM_PID'};
    end
    
    properties(SetObservable,GetObservable,AbortSet)
        % these property control camera property if you add things here they
        % MUST be updated in the private property 'property' and 'GetPropsRO'.
        
        % Integration time in us for the camera
        % 
        % access: read/write
        IntegrationTime;
        
        % Fan controls the cooler. Set to 1 for on, 0 for off.
        % 
        % access: read/write
        Fan;
        
        % ADC reference voltage in mV(Range 2000-4000 or so)
        % 
        % access: read/write
        ADCVREF;
        
        % ADC suppply voltage in mV(Range 2000-4000 or so)
        % 
        % access: read/write
        ADCVIN;
        
        % Gain mode for XEVA 640(AAO) camera. 0-3(low to high)
        % 
        % access: read/write
        Gain;
        
        % Low Gain mode for XEVA 320(USYD) camera. 1 is low, 0 is high.
        % 
        % access: read/write
        LowGain;
        
        % Target temperature for cooler in Kelvin.
        % 
        % access: read/write
        SETTLE;
        
        ImageSource;
        
        BitShift;
        
        TemperatureOffset;
    end
    
    % read only property
    properties(GetObservable)
        % logical is camera initialised in API.
        % 
        % access: read only
        isCameraInit;
        
        % current camera temp in Kelvin.
        % 
        % access: read only
        Temperature; % readonly
        
        % camera serial numer
        % 
        % NB the property in SDK has an '_' in front of name. This is added when
        % property is set by the xenethSDK.SetPropertyValue method(private).
        % 
        % access: read only
        CAM_SER;
        
        % camera PID(product id)
        % 
        % NB the property in SDK has an '_' in front of name. This is added when
        % property is set by the xenethSDK.SetPropertyValue method(private).
        % 
        % access: read only
        CAM_PID;
        
        % logical is camera capturng in API.
        % 
        % access: read only
        isCapturing;
    end
    
    % read only property - don't list
    properties(GetObservable)
        % returns new image via XC_GetFrame call.
        % 
        % access: read only
        % 
        % see also: frame, getNewFrame(private method)
        image; % image from sensor
        
        % structure for image property(frame size in bytes, height, width,
        % and buffer ptr)
        % 
        % frame.size - frame size in bytes via XC_GetFrameSize.
        % frame.width - frame width in pixels via XC_GetWidth.
        % frame.height - frame heigth in pixels via XC_GetHeight
        % frame.buffer - ptr to array required by XC_GetFrame.(Type - 'uint16Ptr', Size - frame.size/2)
        % 
        % access: read only
        frame;
        
        % stores last returned error/response from API calls. Use
        % xenethSDK.Error2String for readable form.
        % 
        % access: read only
        % see also: image, getNewFrame(private method), GetFrameSpecs(private method)
        XenError = 0;
    end
    
    
    % public methods
    methods
        function this = xenethSDK(device)
            % load xenethAPI, connect and init's the camera. Setup listeners for property changes/queries.
            % 
            % If library is loaded, it is unloaded and reloaded.
            % Camera handle is stored in cam_ptr property(private).
            % Camera capture is started after init.
            % 
            % Execute with device as argument ie 'soft://0'.  No argument
            % defaults to 'cam://0'
            if nargin == 0
                this.device = 'cam://0';
            else
                this.device = device;
            end
            
            if libisloaded(this.shrlib)
                unloadlibrary(this.shrlib);
            end
            
            if strcmp(computer,'PCWIN64')
                disp('loading 64 bit dll');
                protofile = @xeneth64_proto;
                dll = 'C:\Program Files\Common Files\XenICs\Runtime\xeneth64.dll';
            else
				disp('loading 32 bit dll');
                protofile = @xeneth_proto;
                %dll = 'C:\Program Files (x86)\Common Files\XenICs\Runtime\xeneth.dll';
                dll = 'C:\Program Files\Common Files\XenICs\Runtime\xeneth.dll';
            end
           
            warning off MATLAB:loadlibrary:TypeNotFound
							loadlibrary(dll, protofile, 'alias', this.shrlib);
            warning on MATLAB:loadlibrary:TypeNotFounds
            
            % Open the camera, cam_ptr is pointer to camera
            lib_ptr = libpointer('cstring',this.device);
            this.cam_ptr = calllib(this.shrlib,'XC_OpenCamera',lib_ptr,[],[]);
            
            this.isCameraInit = calllib(this.shrlib,'XC_IsInitialised',this.cam_ptr);
                
            % sof camera settings
            %             if strcmp(this.device,'soft://0')
            %                 sdisp('soft camera in use')
            %                 [~,~,~] = calllib(this.shrlib,'XC_SetPropertyValueL',this.cam_ptr,'ImageSource',0,'');
            %                 [~,~,~] = calllib(this.shrlib,'XC_SetPropertyValueL',this.cam_ptr,'BitShift',1,'');
            %             end
            % 
            % setup listeners
            
            % property categories
            % property can read/write
            property = {'IntegrationTime','Fan','ADCVREF','ADCVIN','Gain','LowGain','SETTLE','ImageSource','BitShift','TemperatureOffset'};
            
            % getpropsRO are read only property of camera. Attempting to set
            % them will not call SetPropertyValue.
            GetPropsRO = {'Temperature','CAM_SER','CAM_PID'};
            
            % set listeners for read/write property
            for i = 1:length(this.property)
                this.setlh.(this.property{i}) = addlistener(this,this.property{i},'PostSet',...
                    @(src, event) SetPropertyValue(this, src, event,this.property{i}));
                
                this.getlh.(this.property{i}) = addlistener(this,this.property{i},'PreGet',...
                    @(src, event) GetPropertyValue(this, src, event,this.property{i}));
            end
            
            % set listeners for read only property
            for i = 1:length(this.GetPropsRO)
                this.getlh.(this.GetPropsRO{i}) = addlistener(this,this.GetPropsRO{i},'PreGet',...
                    @(src, event) GetPropertyValueReadOnly(this, src, event,this.GetPropsRO{i}));
            end
            
            % add listeners for other properties:
            addlistener(this,'isCameraInit','PreGet',@this.CameraIsInitialised);
            % addlistener(this,'image','PreGet',@this.getNewFrame);
            addlistener(this,'frame','PreGet',@this.GetFrameSpecs);
            
            addlistener(this,'isCapturing','PreGet',@this.CameraIsCapturing);
            if this.isCameraInit
                a = this; % get camera defaults
                % this.startCapture;
            end
        end
  
        function string = xenErrorStr(this)
            % Converts current XenError to human readable form.
            % 
            % Uses XC_ErrorToString call
            [~, string] = calllib(this.shrlib,'XC_ErrorToString',this.XenError,blanks(128),128);
        end
                
        function startCapture(this)
            % Start camera capture
            % 
            % calllib(this.shrlib,'XC_StartCapture',this.cam_ptr);
            [error] = calllib(this.shrlib,'XC_StartCapture',this.cam_ptr);
            this.XenError = error;
            if this.XenError
                warning(['xeneth error' this.xenErrorStr]);
            end
        end
        
        function reInitCam(this)
            calllib(this.shrlib,'XC_CloseCamera',this.cam_ptr);
            ptr = libpointer('cstring',this.device);
            this.cam_ptr = calllib(this.shrlib,'XC_OpenCamera',ptr,[],[]);
            this.isCameraInit = calllib(this.shrlib,'XC_IsInitialised',this.cam_ptr);
            a = this; % re-update settings
        end
            
        function stopCapture(this)
            % Stop camera capture
            % 
            % uses calllib(this.shrlib,'XC_StopCapture',this.cam_ptr);
            [error] = calllib(this.shrlib,'XC_StopCapture',this.cam_ptr);
            this.XenError = error;
            if this.XenError
                warning(['xeneth error' this.xenErrorStr]);
            end
        end
           
        function delete(this)
            % cleanly close camera connecton if deleted
            % 
            % stops capture, close's camera and unloads shared library
            if libisloaded(this.shrlib)
                if this.isCapturing
                    this.stopCapture;
                    if this.isCameraInit
                        calllib(this.shrlib,'XC_CloseCamera',this.cam_ptr);
                    end
                end
                unloadlibrary(this.shrlib);
            end
        end
                
        function XenethProp = list_all_prop(this)
            % gets list of propertes available for xeneth current camera
            % 
            % show list of avalaible property for current loaded camera. And
            % makes their names matlab variable name compliant.
            
            procount = calllib('camlib','XC_GetPropertyCount',this.cam_ptr);
            for i = 0:procount-1
                [~, name] = calllib('camlib','XC_GetPropertyName',this.cam_ptr,i,blanks(61),61);
                [~,~,value] = calllib('camlib','XC_GetPropertyValueL',this.cam_ptr,name,0);
                
                XenethProp.(['x' regexprep(name, '\(|\)$','_')]) = value;
                % XenethProp(i+1).name = name;
                % XenethProp(i+1).value = value;
            end
        end

        function val = get.image(this)
            % gets new frame from active camera using XC_GetFrame.
            % 
            % it loads the frame property(thus updating it) and then gets a
            % frame, formats and saves to the image property.
            frm = this.frame;
            [xenerror, frameptr] = calllib(this.shrlib,'XC_GetFrame',this.cam_ptr,0,2,frm.buffer,frm.size);
            this.XenError = xenerror;

            if this.XenError
                warning('xenethSDK:NoNewFramesAvaliable',this.xenErrorStr);
                %val = [];
                val = xenerror; % Unambiguously communicate error to calling function
            else
                setdatatype(frameptr, 'uint16Ptr', frm.width,frm.height);
                im_struct = get(frameptr);
                val = im_struct.Value';
            end
        end
        
% my newys!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
				function val = frameCount(this)
            % gets frame count from active camera using XC_GetFrameCount.
            val = calllib(this.shrlib,'XC_GetFrameCount',this.cam_ptr);
        end
        
        % Error while evaluating TimerFcn for timer 'perform_soft_trigger'
        % There is no enumerated value named 'XGF_Blocking'.
        % No method with matching signature.
        % The 'XGF_Blocking' enumerated value is invalid.
        
        % Enable frame capture with blocking blocking for software trigger use.
        function val = getFrameWiBlock(this)
					% gets new frame from active camera using XC_GetFrame.
					% Blocks buffer read until buffer ready using XGF_Blocking 'Get Frame' flags
					% frame, formats and saves to the image property.
					frm = this.frame;
					            % [xenerror, frameptr] = calllib(this.shrlib,'XC_GetFrame',this.cam_ptr,'FT_NATIVE',0, ...
					                                     % frm.buffer,frm.size);
					% [xenerror, frameptr] = calllib(this.shrlib,'XC_GetFrame',this.cam_ptr,'FT_NATIVE', ...
														% 'XGF_Blocking',frm.buffer,frm.size);
					[xenerror, frameptr] = calllib(this.shrlib,'XC_GetFrame',this.cam_ptr, ...
														'XGF_Blocking',1,frm.buffer,frm.size);
					this.XenError = xenerror;                    
					disp('getFrameWiBlock');
					%
					if this.XenError
						warning('xenethSDK:NoNewFramesAvaliable',this.xenErrorStr);
						val = [];
					else
						setdatatype(frameptr, 'uint16Ptr',frm.width,frm.height);
						im_struct = get(frameptr);
						val = im_struct.Value';
					end
				end
        
				% Configure the trigger, we want to receive a new frame when a software trigger is triggered.
        function val = enableSoftTrigger(this)
            % update value from camera
            [error,~,val] = calllib(this.shrlib,'XC_SetPropertyValueL',this.cam_ptr,'SoftTriggerEnabled',1,'');
            %
            if this.XenError
                warning(['xeneth error' this.xenErrorStr]);
            end
					disp(error);disp(val);
				end
				
							
				% % disable the trigger
        % function val = disableSoftTrigger(this)
            % % update value from camera
            % [error,~,val] = calllib(this.shrlib,'XC_SetPropertyValueL',this.cam_ptr,'SoftTriggerEnabled',0,'');
            % %
            % if this.XenError
                % warning(['xeneth error' this.xenErrorStr]);
            % end
					% disp(error);disp(val);
				% end
    
				% Once trigger is set up and the frame acquisition is running, generate trigger.
        function val = effectSoftTrigger(this)
            % update value from camera
            [error,~,val] = calllib(this.shrlib,'XC_SetPropertyValueL',this.cam_ptr,'SoftwareDoTrigger',1,'');
            %
            if this.XenError
                warning(['xeneth error' this.xenErrorStr]);
            end
					disp(error);disp(val);
				end
		
		end
    % private methds used by listener events
    methods(Access = private, Hidden = false)
        
        function CameraIsInitialised(this,src,event)
            %  isCameraInit preget listener call back.
            % 
            % Uses the XC_IsInitialised call
            % Check camera initialisation status. Returns 1 is true, 0 if false.
            this.isCameraInit = calllib(this.shrlib,'XC_IsInitialised',this.cam_ptr);
        end
                
        function CameraIsCapturing(this,src,event)
            % isCaptureing lister callback
            % 
            % preget listener callback to to check if camera is capturing.
            this.isCapturing = calllib(this.shrlib,'XC_IsCapturing',this.cam_ptr);
        end
        
        % Called when a SetObservable property is changed.
        % 
        % The source property is in the API. Thus property names must
        % correspond to XenethAPI name.
        % src.Name is name of property that was changed
        % event.AffectedObject.(src.Name) accesses its new value.
        function SetPropertyValue(this,src,event,propname)
            % stop get listener
            this.getlh.(propname).Enabled = false;
            
            % disp['SetPropertyValue called by: ' propname])
            
            % get new value
            value = event.AffectedObject.(propname);
            
            % pass change to camera
            [error,~,~] = calllib(this.shrlib,'XC_SetPropertyValueL',this.cam_ptr,propname,value,'');
            
            % this.(src.Name) = event.AffectedObject.(src.Name);
            this.XenError = error;
            if this.XenError
                warning(['xeneth error' this.xenErrorStr]);
            end
            
            % restart get listerner
            this.getlh.(propname).Enabled = true;
            % disp['SetPropertyValue completed by: ' propname])
        end
        
        % Called just before a GetObservable property is queried, thus providing
        % a fresh value.
        % 
        % The source property is in the API. Thus property names must
        % correspond to XenethAPI name.
        % checks for property that have names not compliant with
        % matlab variable name rules. i.e. staritn with '_'.
        function value = GetPropertyValue(this,src,event,propname)
            % disp['GetPropertyValue called by: ' propname])
            
            % stop set listener
            this.setlh.(propname).Enabled = false;
            
            % update value from camera
            [error,~,value] = calllib(this.shrlib,'XC_GetPropertyValueL',this.cam_ptr,[propname],0);
  
            % set new values

            event.AffectedObject.(propname) = value;
            event.AffectedObject.XenError = error;
            
            if this.XenError
                warning(['xeneth error' this.xenErrorStr]);
            end
            
            % restart set listerner
            this.setlh.(propname).Enabled = true;
        end
        
        % Called just before a GetObservable property is queired, thus providing
        % a fresh value\\
        % 
        % The source property is in the API. Thus property names must
        % correspond to XenethAPI name.
        % checks for property that have names not compliant with
        % matlab variable name rules. i.e. staritn with '_'.
        function value = GetPropertyValueReadOnly(this,src,event,propname)
            % disp['GetPropertyValueReadOnly called by: ' propname])
            
            % check for non-compliant property names.
            if(strcmp('CAM_SER',propname) || strcmp('CAM_PID',propname))
                append = '_';
            else
                append = '';
            end
            
            % update value from camera
            [error,~,value] = calllib(this.shrlib,'XC_GetPropertyValueL',this.cam_ptr,[append propname],0);
            
            % set new values
            event.AffectedObject.(propname) = value;
            event.AffectedObject.XenError = error;
            if this.XenError
                warning(['xeneth error' this.xenErrorStr]);
            end
        end
        
        
        % creates/updates the frame structrue with frame structure for image specs
        % ie frame size in bytes, height, width, and buffer ptr)
        % 
        % frame.size - frame size in bytes via XC_GetFrameSize.
        % frame.width - frame width in pixels via XC_GetWidth.
        % frame.height - frame heigth in pixels via XC_GetHeight
        % frame.buffer - ptr to array required by XC_GetFrame.(Type - 'uint16Ptr', Size - frame.size/2)
        function GetFrameSpecs(this,src,event)
            %             disp('GetFrameSpecs test')
            %             this.frame.size = 1;
            %             return
            % get frame specs
            frm.size = calllib(this.shrlib,'XC_GetFrameSize',this.cam_ptr);
            frm.width = calllib(this.shrlib,'XC_GetWidth',this.cam_ptr);
            frm.height = calllib(this.shrlib,'XC_GetHeight',this.cam_ptr);
            frm.buffer = libpointer('uint16Ptr',zeros(1,frm.size/2,'uint16'));
            this.frame = frm;
        end
    end
end