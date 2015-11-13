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

% Last Modified by GUIDE v2.5 24-Oct-2015 14:51:29

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

%defaultRemoteIP = '10.88.18.1';
defaultRemoteIP = '129.78.100.210';
%defaultRemotePort = 9090;
%defaultLocalPort = 9091;
defaultRemotePort = 9091; 
defaultLocalPort = 9090; 
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
setappdata(handles.guihandle,'photomPosns',zeros(8,2)+10);
setappdata(handles.guihandle,'lastPicked',1);
setappdata(handles.guihandle,'photomFluxes',zeros(8,1));
colormap(handles.mainAxes,'jet')

% Set up UDP object for remote photometry
remoteIP = get(handles.remoteIPBox,'String');
remotePort = str2double(get(handles.remotePortBox,'String'));
localPort = str2double(get(handles.localPortBox,'String'));
udpAI = udp(remoteIP, remotePort, 'LocalPort', localPort);
udpAI.Terminator='';
fopen(udpAI);
setappdata(handles.guihandle,'udpAIobject',udpAI);


% Setup timers
handles.vidTimer = timer(...
    'ExecutionMode', 'fixedRate', ...
    'Period', 1/videoFrameRate, ...
    'TimerFcn', {@updateVideoFn,hObject} );
setappdata(handles.guihandle,'videoState',false)

handles.valTimer = timer(...
    'ExecutionMode', 'fixedRate', ...
    'Period', 0.25, ...
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
    curImNoDark=imdata;
    
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
            
%             frm=getappdata(handles.guihandle,'frm');
%             lineNum=str2double(get(handles.lineNumBox,'String'));
%             hold(handles.mainAxes,'on')
%             plot([1,frm.width], [lineNum, lineNum],'c:','Parent',handles.mainAxes)
%             hold(handles.mainAxes,'off')
        end
        
    else
        
        rect = getappdata(handles.guihandle,'boxCoords');
        subIm = imdata(rect(2):(rect(2)+rect(4)-1), rect(1):(rect(1)+rect(3)-1));
        imagesc(subIm,'Parent',handles.mainAxes,clims)
        set(handles.mainAxes,'XTickLabel','')
        set(handles.mainAxes,'YTickLabel','')
        set(handles.zoomedText,'Visible','on')
        
    end

    % Plot the photometric tap boxes
    photomPosns = getappdata(handles.guihandle,'photomPosns');
    photomSize = str2double(get(handles.photomSizeBox,'String'));

    lp=getappdata(handles.guihandle,'lastPicked');
    rx(1) = round(photomPosns(lp,1)-photomSize/2);
    rx(2) = round(photomPosns(lp,2)-photomSize/2);
    rx(3) = round(photomSize);
    rx(4) = round(photomSize);
    photBoxIm = imdata(rx(2):(rx(2)+rx(4)-1), rx(1):(rx(1)+rx(3)-1));
    imagesc(photBoxIm,'Parent',handles.photomBoxAxes,clims)
    set(handles.photomBoxAxes,'XTickLabel','')
    set(handles.photomBoxAxes,'YTickLabel','')
    
    if get(handles.showBoxCheckbox,'Value') == 1                
        if get(handles.zoomCheckbox,'Value') == 1
            rect = getappdata(handles.guihandle,'boxCoords');
            photomPosns(:,1) = photomPosns(:,1) - rect(1) + 1;
            photomPosns(:,2) = photomPosns(:,2) - rect(2) + 1;
        end
        
        hold(handles.mainAxes,'on')
        rx=zeros(4,1);
        for m = 1:8     
            plot(photomPosns(m,1),photomPosns(m,2),'gx','Parent',handles.mainAxes)
            rx(1) = photomPosns(m,1)-photomSize/2;
            rx(2) = photomPosns(m,2)-photomSize/2;
            rx(3) = photomSize;
            rx(4) = photomSize;
            rectangle('Position',rx,'EdgeColor','r','Linestyle','-','Parent',handles.mainAxes)
        end           
        hold(handles.mainAxes,'off')
    end
    
    
    % Send photometry if in remote mode
    % Set up UDP object if in remote acq mode
    if get(handles.remoteAcqModeCheckbox,'Value') == 1
%         %This is now done in the setup        
%         remoteIP = get(handles.remoteIPBox,'String');
%         remotePort = str2double(get(handles.remotePortBox,'String'));
%         localPort = str2double(get(handles.localPortBox,'String'));
%         udpAI = udp(remoteIP, remotePort, 'LocalPort', localPort);
%         fopen(udpAI);
        udpAI = getappdata(handles.guihandle,'udpAIobject');

        % Check if there's a command in the buffer
        if udpAI.BytesAvailable >= 3
            cmdIn = fscanf(udpAI);
            
            switch cmdIn
                case 'acq'
                    % Send the values
                    set(handles.acquireText,'Visible','on');
                    %pause(0.01) % Can probably remove this
                    drawnow
                    
                    % Measure photometric channels
                    photomPosns = getappdata(handles.guihandle,'photomPosns');
                    photomSize = str2double(get(handles.photomSizeBox,'String'));
                    rx=zeros(4,1);
                    photomFluxes=zeros(8,1);
                    darkFrame = getappdata(handles.guihandle,'darkFrame');
                    if get(handles.photomUseDarkCheckbox,'Value') == 1
                         if sum(darkFrame(:)) ~= 0 
                             imdataP = curImNoDark - darkFrame;
                         else
                             errordlg('You must take a dark frame first','Dark frame not set')
                             set(handles.photomUseDarkCheckbox,'Value',0)
                             imdataP=curImNoDark;
                         end
                    else
                        imdataP=curImNoDark;
                    end
                    for k = 1:8
                        rx(1) = round(photomPosns(k,1)-photomSize/2);
                        rx(2) = round(photomPosns(k,2)-photomSize/2);
                        rx(3) = round(photomSize);
                        rx(4) = round(photomSize);
                        photBoxIm = imdataP(rx(2):(rx(2)+rx(4)-1), rx(1):(rx(1)+rx(3)-1));
                        flux = sum(photBoxIm(:));
                        photomFluxes(k) = flux;
                    end
                    
                    fwrite(udpAI, photomFluxes, 'double')
                    
                    set(handles.acquireText,'Visible','off');
                    
                otherwise
                    disp('Received unknown command')
            end
        end
        
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


% Measure photometric channels
photomPosns = getappdata(handles.guihandle,'photomPosns');
photomSize = str2double(get(handles.photomSizeBox,'String'));
rx=zeros(4,1);
photomFluxes=zeros(8,1);
darkFrame = getappdata(handles.guihandle,'darkFrame');
if get(handles.photomUseDarkCheckbox,'Value') == 1
     if sum(darkFrame(:)) ~= 0 
         imdata = curImNoDark - darkFrame;
     else
         errordlg('You must take a dark frame first','Dark frame not set')
         set(handles.photomUseDarkCheckbox,'Value',0)
         imdata=curImNoDark;
     end
else
    imdata=curImNoDark;
end

for k = 1:8
    rx(1) = round(photomPosns(k,1)-photomSize/2);
    rx(2) = round(photomPosns(k,2)-photomSize/2);
    rx(3) = round(photomSize);
    rx(4) = round(photomSize);
    photBoxIm = imdata(rx(2):(rx(2)+rx(4)-1), rx(1):(rx(1)+rx(3)-1));
    flux = sum(photBoxIm(:));
    photomFluxes(k) = flux;
end

set(handles.pickTxt1,'String',num2str(photomFluxes(1)));
set(handles.pickTxt2,'String',num2str(photomFluxes(2)));
set(handles.pickTxt3,'String',num2str(photomFluxes(3)));
set(handles.pickTxt4,'String',num2str(photomFluxes(4)));
set(handles.pickTxt5,'String',num2str(photomFluxes(5)));
set(handles.pickTxt6,'String',num2str(photomFluxes(6)));
set(handles.pickTxt7,'String',num2str(photomFluxes(7)));
set(handles.pickTxt8,'String',num2str(photomFluxes(8)));



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
cam.SETTLE=str2double(get(hObject,'String'));

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

udpAI = getappdata(handles.guihandle,'udpAIobject');
fclose(udpAI);
delete(udpAI)

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
numFiles = str2double(get(handles.numFilesBox,'String'));

% Set up UDP object if in remote acq mode
if get(handles.remoteAcqModeCheckbox,'Value') == 1
    udpAI = getappdata(handles.guihandle,'udpAIobject');    
    udpWaitIts = 1000; %Wait for command this*0.01s. 
end

% fileString = [datapath filename '.fits'];
% if exist(fileString,'file')
%     oldText = get(handles.videoStatusText,'String');
%     set(handles.videoStatusText,'String','FILE EXISTS - Append Time')
%     set(handles.videoStatusText,'ForegroundColor',[1 0 0])
%     pause(1)
%     set(handles.videoStatusText,'String',oldText)
%     set(handles.videoStatusText,'ForegroundColor',[0 0 0])
% end

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

    
for fileNum = 1:numFiles
    
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
                            disp([datestr(clock,'HH:MM:SS.FFF') ' Acquiring image by remote trigger'])
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
        imageCube(:,:,frame) = imdata;
        messageText = ['Acquired frame ' num2str(frame)];
        set(handles.videoStatusText,'String',messageText)

        % If in remote acuistion mode, send confirmation
        if get(handles.remoteAcqModeCheckbox,'Value') == 1
            fprintf(udpAI,'cnf');
        end
        
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
    pause(1) %%%%%TODO
    fileString = [datapath filename '_' datestr(now,30) '.fits'];
    %fitswrite(imageCube, fileString);
    % Use fits_write since it allows header info to be saved
    fits_write(fileString, imageCube, fitsHeader);
    
end

if videoWasRunning
    cam.startCapture;
    start(handles.vidTimer);
    setappdata(handles.guihandle,'videoState',true)
    set(handles.videoStatusText,'String','Video Running')
else
    set(handles.videoStatusText,'String','Video Stopped')
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

if get(hObject,'Value') == 1
    if getappdata(handles.guihandle,'videoState')
        errordlg('NOTE: In this version, you must manually set the number of frames and filename when doing a remote cube acquisition. I''ll fix this later. Deal with it.','Warning - set frame info if necessary')

        set(handles.remoteAcqModeCheckbox,'ForegroundColor',[1 0 0]);
        set(handles.remotePanel,'ForegroundColor',[1 0 0]);
        set(handles.remotePanel,'ShadowColor',[1 0 0]);
        set(handles.acquirePanel,'ForegroundColor',[1 0 0]);
        set(handles.acquirePanel,'ShadowColor',[1 0 0]);
    else
        errordlg('Video must be running to do this','Video not running')
        set(handles.remoteAcqModeCheckbox,'Value',0);
    end
else
    set(handles.remoteAcqModeCheckbox,'ForegroundColor',[0 0 0]);
    set(handles.remotePanel,'ForegroundColor',[0 0 0]);
    set(handles.remotePanel,'ShadowColor',[0.5 0.5 0.5]);
    set(handles.acquirePanel,'ForegroundColor',[0 0 0]);
    set(handles.acquirePanel,'ShadowColor',[0.5 0.5 0.5]);
end

   

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
                            disp([datestr(clock,'HH:MM:SS.FFF') ' Acquiring image by remote trigger'])
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




% --- Executes on button press in pickBtn1.
function pickBtn1_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,1)


function pickPhotomBox(handles,chan)
% % Stop video timer if running 
% cam=getappdata(handles.guihandle,'camobj');
% if getappdata(handles.guihandle,'videoState')
%     videoWasRunning = true;
%     cam.stopCapture;
%     stop(handles.vidTimer);
%     setappdata(handles.guihandle,'videoState',false)
%     set(handles.videoStatusText,'String','Video Stopped')
% else
%     videoWasRunning = false;
% end

oldText = get(handles.videoStatusText,'String');
set(handles.videoStatusText,'String','SELECT BOX CENTRE')
set(handles.videoStatusText,'ForegroundColor',[1 0 0])

photomPosns = getappdata(handles.guihandle,'photomPosns');
waitforbuttonpress;
curCurs=get(handles.mainAxes,'currentpoint');
xPos = round(curCurs(1,1));
yPos = round(curCurs(1,2));
if get(handles.zoomCheckbox,'Value') == 1
    rect = getappdata(handles.guihandle,'boxCoords');
    yPos = yPos + rect(2) - 1;
    xPos = xPos + rect(1) - 1;
end
photomPosns(chan,1) = xPos;
photomPosns(chan,2) = yPos;
%photomPosns
setappdata(handles.guihandle,'photomPosns',photomPosns);
setappdata(handles.guihandle,'lastPicked',chan)

set(handles.videoStatusText,'String',oldText)
set(handles.videoStatusText,'ForegroundColor',[0 0 0])

% if videoWasRunning
%     cam.startCapture;
%     start(handles.vidTimer);
%     setappdata(handles.guihandle,'videoState',true)
%     set(handles.videoStatusText,'String','Video Running')
% else
%     set(handles.videoStatusText,'String','Video Stopped')
% end



% --- Executes on button press in photomUseDarkCheckbox.
function photomUseDarkCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to photomUseDarkCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of photomUseDarkCheckbox


% --- Executes on button press in pickBtn2.
function pickBtn2_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,2)

% --- Executes on button press in pickBtn3.
function pickBtn3_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,3)

% --- Executes on button press in pickBtn4.
function pickBtn4_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,4)

% --- Executes on button press in pickBtn5.
function pickBtn5_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,5)

% --- Executes on button press in pickBtn6.
function pickBtn6_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,6)

% --- Executes on button press in pickBtn7.
function pickBtn7_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,7)

% --- Executes on button press in pickBtn8.
function pickBtn8_Callback(hObject, eventdata, handles)
% hObject    handle to pickBtn8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pickPhotomBox(handles,8)


function darkFileBox_Callback(hObject, eventdata, handles)
% hObject    handle to darkFileBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of darkFileBox as text
%        str2double(get(hObject,'String')) returns contents of darkFileBox as a double
datapath = get(handles.datapathBox,'String');
fileString = [datapath get(hObject,'String') '.fits'];
try
    inCube = fitsread(fileString);
    darkFrame = uint16(mean(inCube,3));
    setappdata(handles.guihandle,'darkFrame',darkFrame);
catch err
    errordlg('Cannot open file - does it exist?','Cannot open file')
end


% --- Executes during object creation, after setting all properties.
function darkFileBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to darkFileBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function photomSizeBox_Callback(hObject, eventdata, handles)
% hObject    handle to photomSizeBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of photomSizeBox as text
%        str2double(get(hObject,'String')) returns contents of photomSizeBox as a double


% --- Executes during object creation, after setting all properties.
function photomSizeBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to photomSizeBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function photomPosnSavefileBox_Callback(hObject, eventdata, handles)
% hObject    handle to photomPosnSavefileBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of photomPosnSavefileBox as text
%        str2double(get(hObject,'String')) returns contents of photomPosnSavefileBox as a double


% --- Executes during object creation, after setting all properties.
function photomPosnSavefileBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to photomPosnSavefileBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in photomSaveBtn.
function photomSaveBtn_Callback(hObject, eventdata, handles)
% hObject    handle to photomSaveBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
photomPosns = getappdata(handles.guihandle,'photomPosns');
filename=get(handles.photomPosnSavefileBox,'String');
save(filename,'photomPosns')

% --- Executes on button press in photomLoadBtn.
function photomLoadBtn_Callback(hObject, eventdata, handles)
% hObject    handle to photomLoadBtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
filename=get(handles.photomPosnSavefileBox,'String');
load(filename)
setappdata(handles.guihandle,'photomPosns',photomPosns);





function numFilesBox_Callback(hObject, eventdata, handles)
% hObject    handle to numFilesBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of numFilesBox as text
%        str2double(get(hObject,'String')) returns contents of numFilesBox as a double


% --- Executes during object creation, after setting all properties.
function numFilesBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to numFilesBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
