function varargout = XenicsLight(varargin)
% XENICSLIGHT MATLAB code for XenicsLight.fig
%      XENICSLIGHT, by itself, creates a new XENICSLIGHT or raises the existing
%      singleton*.
%
%      H = XENICSLIGHT returns the handle to a new XENICSLIGHT or the handle to
%      the existing singleton*.
%
%      XENICSLIGHT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in XENICSLIGHT.M with the given input arguments.
%
%      XENICSLIGHT('Property','Value',...) creates a new XENICSLIGHT or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before XenicsLight_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to XenicsLight_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help XenicsLight

% Last Modified by GUIDE v2.5 21-Jul-2015 16:30:16

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @XenicsLight_OpeningFcn, ...
                   'gui_OutputFcn',  @XenicsLight_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before XenicsLight is made visible.
function XenicsLight_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to XenicsLight (see VARARGIN)


%%%%%%%%%%%%%%%%%% Camera type %%%%%%%%%%%%%%%%%%
% Different Xenics models handle Gain in different ways.
% So far this code supports the 320x256 type (i.e. the Sydney type)
% and the 640x512 type (i.e. the AAO type). 
% The 320 only has two modes (1 ('low') or 0 ('high') ).
% Uncomment appropriate line:
%cameraType = 320;
cameraType = 640;

videoFrameRate = 25; %FPS for live video

defaultRemoteIP = '10.88.18.1';
defaultRemotePort = 9090;
defaultLocalPort = 9091;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%






% Choose default command line output for XenicsLight
handles.output = hObject;

% store guihandle in standard form
handles.guiname=mfilename;
handles.guihandle=handles.(handles.guiname);

warning('off','xenethSDK:NoNewFramesAvaliable');

%init camera
cam=xenethSDK;
%%%cam.startCapture;
setappdata(handles.guihandle,'camobj',cam);

% start cooler
cam.Fan=1; %Fan on
cam.SETTLE=160; %SetCoolingTemperature (K)
set(handles.tempSetBox,'String',cam.SETTLE);
cam.TemperatureOffset=0;


% Get existing settings from camera and write to text boxes
set(handles.intTimeBox,'String',num2str(cam.IntegrationTime));
set(handles.adcVinBox,'String',num2str(cam.ADCVIN));
set(handles.adcVrefBox,'String',num2str(cam.ADCVREF));
set(handles.currentTempText,'String',num2str(cam.Temperature));

setappdata(handles.guihandle,'cameraType',cameraType);
if cameraType == 320
    set(handles.gainSetBox,'String',num2str(cam.LowGain));
else
    set(handles.gainSetBox,'String',num2str(cam.Gain));
end

set(handles.remoteIPBox,'String',defaultRemoteIP)
set(handles.remotePortBox,'String',num2str(defaultRemotePort));
set(handles.localPortBox,'String',num2str(defaultLocalPort));



set(handles.mainAxes,'XTickLabel','')
set(handles.mainAxes,'YTickLabel','')

%get frame info
frm=cam.frame;
setappdata(handles.guihandle,'frm',frm);

darkFrame = zeros(frm.height,frm.width);
setappdata(handles.guihandle,'darkFrame',darkFrame);
curIm = zeros(frm.height,frm.width);
setappdata(handles.guihandle,'curIm',curIm);

% Set initial ROI to be entire frame
boxCoords = [1 1 frm.width frm.height];
setappdata(handles.guihandle,'boxCoords',boxCoords);

setappdata(handles.guihandle,'abortFlag',false);

colormap(handles.mainAxes,'jet')

% Setup timers
handles.vidTimer = timer(...
    'ExecutionMode', 'fixedRate', ...
    'Period', 1/videoFrameRate, ...
    'TimerFcn', {@updateVideoFn,hObject} );
setappdata(handles.guihandle,'videoState',false)

handles.valTimer = timer(...
    'ExecutionMode', 'fixedRate', ...
    'Period', 1, ...
    'TimerFcn', {@updateGUIValues,hObject} );

% Update handles structure
guidata(hObject, handles);

start(handles.valTimer);

% UIWAIT makes XenicsLight wait for user response (see UIRESUME)
% uiwait(handles.XenicsLight);


% --- Outputs from this function are returned to the command line.
function varargout = XenicsLight_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function updateVideoFn(hObject,eventdata,hfigure)
handles = guidata(hfigure);
cam=getappdata(handles.guihandle,'camobj');

imdata=cam.image;
%imdata=get_image(cam);

if imdata == 10008
    % Do nothing, since no new frame is available yet.
    % disp('No frame available.')
else
    setappdata(handles.guihandle,'curIm',imdata);
        
    darkFrame = getappdata(handles.guihandle,'darkFrame');
    if get(handles.subtDarkCheckbox,'Value') == 1
        if sum(darkFrame(:)) ~= 0 
            imdata = imdata - getappdata(handles.guihandle,'darkFrame');
        else
            errordlg('You must take a dark frame first','Dark frame not set')
            set(handles.subtDarkCheckbox,'Value',0)
        end
    end
    
    loLim = str2double(get(handles.stretchLoBox,'String'));
    hiLim = str2double(get(handles.stretchHiBox,'String'));
    clims = [loLim hiLim];

    if get(handles.zoomCheckbox,'Value') == 0
        
        imagesc(imdata,'Parent',handles.mainAxes,clims)
        set(handles.mainAxes,'XTickLabel','')
        set(handles.mainAxes,'YTickLabel','')
        set(handles.zoomedText,'Visible','off')
        
        if get(handles.showBoxCheckbox,'Value') == 1
            rect = getappdata(handles.guihandle,'boxCoords');
            rectangle('Position',rect,'EdgeColor','m','Linestyle','--','Parent',handles.mainAxes)
            
            frm=getappdata(handles.guihandle,'frm');
            lineNum=str2double(get(handles.lineNumBox,'String'));
            hold(handles.mainAxes,'on')
            plot([1,frm.width], [lineNum, lineNum],'c:','Parent',handles.mainAxes)
            hold(handles.mainAxes,'off')
        end
        
    else
        
        rect = getappdata(handles.guihandle,'boxCoords');
        subIm = imdata(rect(2):(rect(2)+rect(4)-1), rect(1):(rect(1)+rect(3)-1));
        imagesc(subIm,'Parent',handles.mainAxes,clims)
        set(handles.mainAxes,'XTickLabel','')
        set(handles.mainAxes,'YTickLabel','')
        set(handles.zoomedText,'Visible','on')
        
    end

end


function updateGUIValues(hObject,eventdata,hfigure)
handles = guidata(hfigure);
cam=getappdata(handles.guihandle,'camobj');

set(handles.currentTempText,'String',num2str(cam.Temperature));

curIm = getappdata(handles.guihandle,'curIm');
if get(handles.subtDarkCheckbox,'Value') == 1
    curIm = curIm - getappdata(handles.guihandle,'darkFrame');
end
rect = getappdata(handles.guihandle,'boxCoords');
subIm = curIm(rect(2):(rect(2)+rect(4)-1), rect(1):(rect(1)+rect(3)-1));
boxSum = sum(subIm(:));
set(handles.boxFluxText,'String',num2str(boxSum,'%.4g'));

curImNoDark = getappdata(handles.guihandle,'curIm');
subImNoDark = curImNoDark(rect(2):(rect(2)+rect(4)-1), rect(1):(rect(1)+rect(3)-1));
set(handles.minText,'String',num2str(min(subImNoDark(:))));
set(handles.maxText,'String',num2str(max(subImNoDark(:))));

curCurs=get(handles.mainAxes,'currentpoint');
set(handles.clickXText,'String',num2str(curCurs(1,1)))
set(handles.clickYText,'String',num2str(curCurs(1,2)))



function intTimeBox_Callback(hObject, eventdata, handles)
% hObject    handle to intTimeBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of intTimeBox as text
%        str2double(get(hObject,'String')) returns contents of intTimeBox as a double
cam=getappdata(handles.guihandle,'camobj');
cam.IntegrationTime=str2double(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function intTimeBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to intTimeBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function tempSetBox_Callback(hObject, eventdata, handles)
% hObject    handle to tempSetBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of tempSetBox as text
%        str2double(get(hObject,'String')) returns contents of tempSetBox as a double
cam=getappdata(handles.guihandle,'camobj');
cam.Temperature=str2double(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function tempSetBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tempSetBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function adcVinBox_Callback(hObject, eventdata, handles)
% hObject    handle to adcVinBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of adcVinBox as text
%        str2double(get(hObject,'String')) returns contents of adcVinBox as a double
cam=getappdata(handles.guihandle,'camobj');
cam.ADCVIN=str2double(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function adcVinBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to adcVinBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function adcVrefBox_Callback(hObject, eventdata, handles)
% hObject    handle to adcVrefBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of adcVrefBox as text
%        str2double(get(hObject,'String')) returns contents of adcVrefBox as a double
cam=getappdata(handles.guihandle,'camobj');
cam.ADCVREF=str2double(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function adcVrefBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to adcVrefBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in startVidBtn.
function startVidBtn_Callback(hObject, eventdata, handles)
% hObject    handle to startVidBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

cam=getappdata(handles.guihandle,'camobj');
if getappdata(handles.guihandle,'videoState') %Stop free-run and video
    cam.stopCapture;
    stop(handles.vidTimer);
    setappdata(handles.guihandle,'videoState',false)
    set(handles.videoStatusText,'String','Video Stopped')
else %Start free-run and video
    cam.startCapture;
    start(handles.vidTimer);
    setappdata(handles.guihandle,'videoState',true)
    set(handles.videoStatusText,'String','Video Running')
end


function gainSetBox_Callback(hObject, eventdata, handles)
% hObject    handle to gainSetBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of gainSetBox as text
%        str2double(get(hObject,'String')) returns contents of gainSetBox as a double
cam=getappdata(handles.guihandle,'camobj');
cameraType = getappdata(handles.guihandle,'cameraType');
gainVal = str2double(get(handles.gainSetBox,'String'));
if cameraType == 320
    if gainVal <= 1
        cam.LowGain = gainVal;
    else
        disp('Gain can only be 0 or 1 for this camera');
    end
else
    if gainVal <= 3
        cam.Gain=gainval;
    else
        disp('Gain must be from 0 to 3 for this camera');
    end
end




% --- Executes during object creation, after setting all properties.
function gainSetBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gainSetBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function datapathBox_Callback(hObject, eventdata, handles)
% hObject    handle to datapathBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of datapathBox as text
%        str2double(get(hObject,'String')) returns contents of datapathBox as a double

% --- Executes during object creation, after setting all properties.
function datapathBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to datapathBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in exitBtn.
function exitBtn_Callback(hObject, eventdata, handles)
% hObject    handle to exitBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
cam=getappdata(handles.guihandle,'camobj');
cam.stopCapture;
stop(handles.vidTimer);
stop(handles.valTimer);
delete(cam)
delete(handles.XenicsLight);
delete(handles.vidTimer);
delete(handles.valTimer);
disp('Exited.');


% --- Executes on button press in takeDarkBtn.
function takeDarkBtn_Callback(hObject, eventdata, handles)
% hObject    handle to takeDarkBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
darkFrame = getappdata(handles.guihandle,'curIm');
setappdata(handles.guihandle,'darkFrame',darkFrame);


% --- Executes on button press in subtDarkCheckbox.
function subtDarkCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to subtDarkCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of subtDarkCheckbox



function savefileBox_Callback(hObject, eventdata, handles)
% hObject    handle to savefileBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of savefileBox as text
%        str2double(get(hObject,'String')) returns contents of savefileBox as a double


% --- Executes during object creation, after setting all properties.
function savefileBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to savefileBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function numFramesBox_Callback(hObject, eventdata, handles)
% hObject    handle to numFramesBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of numFramesBox as text
%        str2double(get(hObject,'String')) returns contents of numFramesBox as a double


% --- Executes during object creation, after setting all properties.
function numFramesBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to numFramesBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in acquireBtn.
function acquireBtn_Callback(hObject, eventdata, handles)
% hObject    handle to acquireBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
cam=getappdata(handles.guihandle,'camobj');
datapath = get(handles.datapathBox,'String');
filename = get(handles.savefileBox,'String');
numFrames = str2double(get(handles.numFramesBox,'String'));

% Set up UDP object if in remote acq mode
if get(handles.remoteAcqModeCheckbox,'Value') == 1
    remoteIP = get(handles.remoteIPBox,'String');
    remotePort = str2double(get(handles.remotePortBox,'String'));
    localPort = str2double(get(handles.localPortBox,'String'));
    udpAI = udp(remoteIP, remotePort, 'LocalPort', localPort);
    fopen(udpAI);
    
    udpWaitIts = 1000; %Wait for command this*0.01s. 
end

fileString = [datapath filename '.fits'];
if exist(fileString,'file')
    oldText = get(handles.videoStatusText,'String');
    set(handles.videoStatusText,'String','FILE ALREADY EXISTS')
    set(handles.videoStatusText,'ForegroundColor',[1 0 0])
    pause(1)
    set(handles.videoStatusText,'String',oldText)
    set(handles.videoStatusText,'ForegroundColor',[0 0 0])

else

    % Stop video timer if running
    if getappdata(handles.guihandle,'videoState')
        videoWasRunning = true;
        cam.stopCapture;
        stop(handles.vidTimer);
        setappdata(handles.guihandle,'videoState',false)
        set(handles.videoStatusText,'String','Video Stopped')
    else
        videoWasRunning = false;
    end
    pause(0.1)


    % Save a cube
    frm=cam.frame;
    imageCube = zeros(frm.height,frm.width,numFrames);
    cam.startCapture;

    set(handles.videoStatusText,'ForegroundColor',[0 0 1])
    tic
    for frame = 1:numFrames
        imdata=cam.image;

        % If in remote acq mode, wait for the acq command
        % Currently uses a loop, TODO use an event of udp object.
        
        if get(handles.remoteAcqModeCheckbox,'Value') == 1
            for jj = 1:udpWaitIts
                if udpAI.BytesAvailable >= 3
                    cmdIn = fscanf(udpAI);
                    switch cmdIn
                        case 'acq'
                            disp('Acquiring image by remote trigger')
                            break
                        otherwise
                            disp('Received unknown command')
                    end
                end
                  
                if jj == udpWaits
                    disp('No UDP command received before timeout!')
                    errordlg('No command received','No UDP command received before timeout!')
                    setappdata(handles.guihandle,'abortFlag',true);
                end
                
                pause(0.01)             
            end
        end
        
        
        % Wait for a new image to be available
        while imdata == 10008
            pause(0.01)
            imdata=cam.image;
        end

        setappdata(handles.guihandle,'curIm',imdata);
        imageCube(:,:,frame) = imdata;
        messageText = ['Acquired frame ' num2str(frame)];
        set(handles.videoStatusText,'String',messageText)

        
        if getappdata(handles.guihandle,'abortFlag')
            disp('Aborting acquisition')
            setappdata(handles.guihandle,'abortFlag',false)
            break
        end
        
    end
    cam.stopCapture;
    set(handles.videoStatusText,'ForegroundColor',[0 0 0])
    
    fitsHeader.DATETIME=datestr(clock,30);
    fitsHeader.T_INT=str2double(get(handles.intTimeBox,'String'));
    fitsHeader.AV_FPS=numFrames/toc;
    fitsHeader.GAIN=str2double(get(handles.gainSetBox,'String'));
    fitsHeader.ADCVIN=str2double(get(handles.adcVinBox,'String'));
    fitsHeader.ADCVREF=str2double(get(handles.adcVrefBox,'String'));
    set(handles.videoStatusText,'String','Saving FITS file')
    %fitswrite(imageCube, fileString);
    % Use fits_write since it allows header info to be saved
    fits_write(fileString, imageCube, fitsHeader);
    
    if videoWasRunning
        cam.startCapture;
        start(handles.vidTimer);
        setappdata(handles.guihandle,'videoState',true)
        set(handles.videoStatusText,'String','Video Running')
    else
        set(handles.videoStatusText,'String','Video Stopped')
    end

end



function stretchLoBox_Callback(hObject, eventdata, handles)
% hObject    handle to stretchLoBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of stretchLoBox as text
%        str2double(get(hObject,'String')) returns contents of stretchLoBox as a double


% --- Executes during object creation, after setting all properties.
function stretchLoBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stretchLoBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function stretchHiBox_Callback(hObject, eventdata, handles)
% hObject    handle to stretchHiBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of stretchHiBox as text
%        str2double(get(hObject,'String')) returns contents of stretchHiBox as a double


% --- Executes during object creation, after setting all properties.
function stretchHiBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stretchHiBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in selectBoxBtn.
function selectBoxBtn_Callback(hObject, eventdata, handles)
% hObject    handle to selectBoxBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Stop video timer if running 
cam=getappdata(handles.guihandle,'camobj');
if getappdata(handles.guihandle,'videoState')
    videoWasRunning = true;
    cam.stopCapture;
    stop(handles.vidTimer);
    setappdata(handles.guihandle,'videoState',false)
    set(handles.videoStatusText,'String','Video Stopped')
else
    videoWasRunning = false;
end
    
oldText = get(handles.videoStatusText,'String');
set(handles.videoStatusText,'String','SELECT RECTANGLE')
set(handles.videoStatusText,'ForegroundColor',[1 0 0])
rect=getrect(handles.mainAxes);
rect=round(rect);
setappdata(handles.guihandle,'boxCoords',rect);
set(handles.videoStatusText,'String',oldText)
set(handles.videoStatusText,'ForegroundColor',[0 0 0])

if videoWasRunning
    cam.startCapture;
    start(handles.vidTimer);
    setappdata(handles.guihandle,'videoState',true)
    set(handles.videoStatusText,'String','Video Running')
else
    set(handles.videoStatusText,'String','Video Stopped')
end



% --- Executes on button press in zoomCheckbox.
function zoomCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to zoomCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of zoomCheckbox


% --- Executes on button press in showBoxCheckbox.
function showBoxCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to showBoxCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of showBoxCheckbox



function remoteIPBox_Callback(hObject, eventdata, handles)
% hObject    handle to remoteIPBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of remoteIPBox as text
%        str2double(get(hObject,'String')) returns contents of remoteIPBox as a double


% --- Executes during object creation, after setting all properties.
function remoteIPBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to remoteIPBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function remotePortBox_Callback(hObject, eventdata, handles)
% hObject    handle to remotePortBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of remotePortBox as text
%        str2double(get(hObject,'String')) returns contents of remotePortBox as a double


% --- Executes during object creation, after setting all properties.
function remotePortBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to remotePortBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function localPortBox_Callback(hObject, eventdata, handles)
% hObject    handle to localPortBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of localPortBox as text
%        str2double(get(hObject,'String')) returns contents of localPortBox as a double


% --- Executes during object creation, after setting all properties.
function localPortBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to localPortBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end






% --- Executes on button press in abortBtn.
function abortBtn_Callback(hObject, eventdata, handles)
% hObject    handle to abortBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
setappdata(handles.guihandle,'abortFlag',true)


% --- Executes on button press in remoteAcqModeCheckbox.
function remoteAcqModeCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to remoteAcqModeCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of remoteAcqModeCheckbox


% --- Executes on button press in lineAcqBtn.
function lineAcqBtn_Callback(hObject, eventdata, handles)
% hObject    handle to lineAcqBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%Force remote mode
set(handles.remoteAcqModeCheckbox,'Value',1);
drawnow

lineNum = str2double(get(handles.lineNumBox,'String'));
if lineNum == 0
    errordlg('No line selected','You must enter the desired line number')
    setappdata(handles.guihandle,'abortFlag',true);
end

numFrames = 121^2*8;
disp(['Using ' num2str(numFrames) ' frames']);
memsScanFilename = 'memsScanLineArray.mat'


cam=getappdata(handles.guihandle,'camobj');
datapath = get(handles.datapathBox,'String');
filename = get(handles.savefileBox,'String');
%numFrames = str2double(get(handles.numFramesBox,'String'));

% Set up UDP object if in remote acq mode
if get(handles.remoteAcqModeCheckbox,'Value') == 1
    remoteIP = get(handles.remoteIPBox,'String');
    remotePort = str2double(get(handles.remotePortBox,'String'));
    localPort = str2double(get(handles.localPortBox,'String'));
    udpAI = udp(remoteIP, remotePort, 'LocalPort', localPort);
    fopen(udpAI);
    
    udpWaitIts = 1000; %Wait for command this*0.01s. 
end

fileString = [datapath filename '.fits'];
if exist(fileString,'file')
    oldText = get(handles.videoStatusText,'String');
    set(handles.videoStatusText,'String','FILE ALREADY EXISTS')
    set(handles.videoStatusText,'ForegroundColor',[1 0 0])
    pause(1)
    set(handles.videoStatusText,'String',oldText)
    set(handles.videoStatusText,'ForegroundColor',[0 0 0])

else

    % Stop video timer if running
    if getappdata(handles.guihandle,'videoState')
        videoWasRunning = true;
        cam.stopCapture;
        stop(handles.vidTimer);
        setappdata(handles.guihandle,'videoState',false)
        set(handles.videoStatusText,'String','Video Stopped')
    else
        videoWasRunning = false;
    end
    pause(0.1)


    % Save a cube
    frm=cam.frame;
    %imageCube = zeros(frm.height,frm.width,numFrames);
    lineArray = zeros(frm.width, numFrames);
    cam.startCapture;

    set(handles.videoStatusText,'ForegroundColor',[0 0 1])
    for frame = 1:numFrames
        imdata=cam.image;

        % If in remote acq mode, wait for the acq command
        % Currently uses a loop, TODO use an event of udp object.
        
        if get(handles.remoteAcqModeCheckbox,'Value') == 1
            for jj = 1:udpWaitIts
                if udpAI.BytesAvailable >= 3
                    cmdIn = fscanf(udpAI);
                    switch cmdIn
                        case 'acq'
                            disp('Acquiring image by remote trigger')
                            break
                        otherwise
                            disp('Received unknown command')
                    end
                end
                  
                if jj == udpWaitIts
                    disp('No UDP command received before timeout!')
                    errordlg('No command received','No UDP command received before timeout!')
                    setappdata(handles.guihandle,'abortFlag',true);
                end
                
                pause(0.01)             
            end
        end
        
        
        % Wait for a new image to be available
        while imdata == 10008
            pause(0.01)
            imdata=cam.image;
        end

        setappdata(handles.guihandle,'curIm',imdata);
        %imageCube(:,:,frame) = imdata;
        lineArray(:,frame) = imdata(lineNum,:);
        messageText = ['Acquired frame ' num2str(frame)];
        set(handles.videoStatusText,'String',messageText)

        
        if getappdata(handles.guihandle,'abortFlag')
            disp('Aborting acquisition')
            setappdata(handles.guihandle,'abortFlag',false)
            break
        end
        
    end
    cam.stopCapture;
    set(handles.videoStatusText,'ForegroundColor',[0 0 0])

    %set(handles.videoStatusText,'String','Saving FITS file')
    %fitswrite(imageCube, fileString);

    set(handles.videoStatusText,'String','Saving MAT file')
    save(memsScanFilename,'lineArray')
    
    if videoWasRunning
        cam.startCapture;
        start(handles.vidTimer);
        setappdata(handles.guihandle,'videoState',true)
        set(handles.videoStatusText,'String','Video Running')
    else
        set(handles.videoStatusText,'String','Video Stopped')
    end

end


function lineNumBox_Callback(hObject, eventdata, handles)
% hObject    handle to lineNumBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of lineNumBox as text
%        str2double(get(hObject,'String')) returns contents of lineNumBox as a double


% --- Executes during object creation, after setting all properties.
function lineNumBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lineNumBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
