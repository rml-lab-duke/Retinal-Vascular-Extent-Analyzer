function rml_lab_gui_v11_clahe
% =========================================================
% RML Lab GUI v11 CLAHE – Quadrant-aware Focal Point Marking Tool
% Copyright (c) 2026 Paula C. Morales. Cesar Estrada P. All rights reserved.
% Duke University Eye Center – Maldonado Lab PI:Ramiro S. Maldonado
% =========================================================
% CHANGES v4.2:
% - Duplicate row warning on save
% - Resume session from .mat files
% - Graded image indicator (✓) in counter
% - Brightness/Contrast sliders
% - Zoom in/out buttons
% CHANGES v4.3:
% - Click+drag to pan (right-click or middle-click + drag)
% - Left-click continues to place markers as before
%
% CHANGES v10 (2026):
% - FIX: Dots now SNAP to exact ring boundary at vessel-crossing angle.
%        Click within ±20 % of ring radius; dot is projected onto ring.
% - FIX: Annotated image export always captures FULL image regardless of
%        zoom/pan state. View is restored after export.
% - NEW: ROI crops (128×128 px) saved to annotated_images/ROI_crops/ at
%        save time. One PNG per vessel crossing, named:
%        {StudyID}_{G}_{Ring}_{Quad}_{nn}_ROI.png

%% ---------------- FIGURE ----------------
hFig = figure('Name','RML Lab v4', ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Units','normalized', ...
    'Position',[0.05 0.05 0.9 0.9]);
uicontrol(hFig,'Style','text', ...
    'String','RML Lab', ...
    'FontSize',16,'FontWeight','bold', ...
    'Units','normalized','Position',[0 0.95 1 0.04], ...
    'HorizontalAlignment','center');

%% ---------------- PANELS ----------------
hLeft = uipanel(hFig,'Units','normalized','Position',[0.01 0.01 0.17 0.93]);
hAx   = axes(hFig,'Units','normalized','Position',[0.20 0.01 0.79 0.93]);
axis(hAx,'off'); hold(hAx,'on');
set(hAx,'PickableParts','all','HitTest','on');

%% ---------------- STATE ----------------
S.img        = [];
S.imgOrig    = [];   % original image for brightness/contrast reset
S.hImg       = [];
S.ON         = [];
S.F          = [];
S.R1         = [];
S.R2         = [];
S.R3         = [];
S.hR1        = [];
S.hR2        = [];
S.hR3        = [];
S.hON        = [];
S.hF         = [];
S.hQuadLines = [];
S.hAllMarks  = [];
S.studyID    = '';
S.currentGroup = 'G1';
S.clickMode  = '';
S.eyeSide    = 'OD';
S.temporalSign = 1;
emptyQ = struct('ST',[],'SN',[],'IT',[],'IN',[]);
emptyR = struct('R1',emptyQ,'R2',emptyQ,'R3',emptyQ);
S.markings = struct('G1',emptyR,'G2',emptyR,'G3',emptyR);
S.imageFiles      = {};
S.currentImageIdx = 0;
S.folderPath      = '';
S.annotatedFolder = '';
S.zoomLevel       = 1.0;
S.roiFolder       = '';   % set when folder is loaded; crops go here
S.roiSize         = 64;   % half-width of ROI crop in pixels → 128×128 total
S.trainingFolder  = '';   % clean TIFF copies for model training go here
% ── PAN STATE ──
S.isPanning   = false;
S.panStartPt  = [];
guidata(hFig,S);

%% ---------------- CONTROLS (left panel) ----------------
y = 0.94; dy = 0.045;

% Study ID
uicontrol(hLeft,'Style','text','String','Study ID', ...
    'Units','normalized','Position',[0.05 y 0.9 0.04],'HorizontalAlignment','left');
y=y-0.02;
hStudyIDEdit = uicontrol(hLeft,'Style','edit','Units','normalized', ...
    'Position',[0.05 y 0.9 0.04],'Callback',@onStudyID);
y=y-0.06;

% Upload Folder
uicontrol(hLeft,'Style','pushbutton','String','Upload Folder', ...
    'Units','normalized','Position',[0.05 y 0.9 0.05], ...
    'Callback',@onUploadFolder,'FontWeight','bold');
y=y-dy;

% Image counter
hImageCounter = uicontrol(hLeft,'Style','text','String','No images loaded', ...
    'Units','normalized','Position',[0.05 y 0.9 0.04],'HorizontalAlignment','center', ...
    'FontSize',9,'ForegroundColor',[0.2 0.4 0.8]);
y=y-0.05;

% Navigation
uicontrol(hLeft,'Style','pushbutton','String','◄ Previous', ...
    'Units','normalized','Position',[0.05 y 0.42 0.05],'Callback',@onPrevious);
uicontrol(hLeft,'Style','pushbutton','String','Next ►', ...
    'Units','normalized','Position',[0.53 y 0.42 0.05],'Callback',@onNext, ...
    'FontWeight','bold');
y=y-0.07;

% Ring marking buttons
uicontrol(hLeft,'Style','text','String','Mark Ring:', ...
    'Units','normalized','Position',[0.05 y 0.9 0.03],'HorizontalAlignment','left','FontSize',8);
y=y-0.04;
uicontrol(hLeft,'Style','pushbutton','String','R1', ...
    'Units','normalized','Position',[0.05 y 0.25 0.05],'Callback',@(~,~)setMode('R1'), ...
    'BackgroundColor',[1 1 0.7],'FontWeight','bold');
uicontrol(hLeft,'Style','pushbutton','String','R2', ...
    'Units','normalized','Position',[0.37 y 0.25 0.05],'Callback',@(~,~)setMode('R2'), ...
    'BackgroundColor',[0.7 1 1],'FontWeight','bold');
uicontrol(hLeft,'Style','pushbutton','String','R3', ...
    'Units','normalized','Position',[0.69 y 0.25 0.05],'Callback',@(~,~)setMode('R3'), ...
    'BackgroundColor',[1 0.8 1],'FontWeight','bold');
y=y-dy;

% Group toggles
uicontrol(hLeft,'Style','text','String','Group:', ...
    'Units','normalized','Position',[0.05 y 0.3 0.04],'HorizontalAlignment','left');
hG1btn = uicontrol(hLeft,'Style','togglebutton','String','G1','Value',1, ...
    'Units','normalized','Position',[0.05 y-dy 0.25 0.05],'Callback',@(s,~)setGroup(s,'G1'));
hG2btn = uicontrol(hLeft,'Style','togglebutton','String','G2', ...
    'Units','normalized','Position',[0.37 y-dy 0.25 0.05],'Callback',@(s,~)setGroup(s,'G2'));
hG3btn = uicontrol(hLeft,'Style','togglebutton','String','G3', ...
    'Units','normalized','Position',[0.69 y-dy 0.25 0.05],'Callback',@(s,~)setGroup(s,'G3'));
y=y-2*dy;

% Mode display
hModeLabel = uicontrol(hLeft,'Style','text','String','Mode: None', ...
    'Units','normalized','Position',[0.05 y 0.9 0.04],'HorizontalAlignment','center', ...
    'ForegroundColor',[0.8 0 0],'FontWeight','bold','FontSize',9);
y=y-0.02;

% Live dot counter
uicontrol(hLeft,'Style','text','String','Saved Markings:', ...
    'Units','normalized','Position',[0.03 y 0.9 0.03],'HorizontalAlignment','center', ...
    'FontSize',8,'ForegroundColor',[0.3 0.3 0.3]);
y=y-0.04;
hDotCounter = uicontrol(hLeft,'Style','text','String','G1 – R1:0  R2:0  R3:0', ...
    'Units','normalized','Position',[0.05 y 0.9 0.02],'HorizontalAlignment','center', ...
    'FontSize',9,'FontWeight','bold','ForegroundColor',[0.7 0.5 0], ...
    'BackgroundColor',[0.99 0.99 0.92]);
y=y-0.05;

% ── BRIGHTNESS / CONTRAST SLIDERS ──
uicontrol(hLeft,'Style','text','String','Enhancement:', ...
    'Units','normalized','Position',[0.05 y 0.55 0.03],'HorizontalAlignment','left','FontSize',8);
uicontrol(hLeft,'Style','pushbutton','String','Reset', ...
    'Units','normalized','Position',[0.65 y 0.3 0.03],'Callback',@resetImage,'FontSize',7);
y=y-0.05;
hEnhanceSlider = uicontrol(hLeft,'Style','slider','Min',0.1,'Max',3.0,'Value',1.0, ...
    'Units','normalized','Position',[0.05 y 0.9 0.03], ...
    'Callback',@onEnhance);
y=y-0.04;
% Fixed, reproducible vessel enhancement (CLAHE). Display only; S.imgOrig is preserved.
uicontrol(hLeft,'Style','pushbutton','String','Vessel Enhance (CLAHE)', ...
    'Units','normalized','Position',[0.05 y 0.9 0.04], ...
    'Callback',@onCLAHE,'FontWeight','bold','FontSize',8);
y=y-0.06;

% ── ZOOM buttons ──
uicontrol(hLeft,'Style','pushbutton','String','+ Zoom', ...
    'Units','normalized','Position',[0.05 y 0.27 0.05],'Callback',@zoomIn,'FontWeight','bold');
uicontrol(hLeft,'Style','pushbutton','String','- Zoom', ...
    'Units','normalized','Position',[0.37 y 0.27 0.05],'Callback',@zoomOut,'FontWeight','bold');
uicontrol(hLeft,'Style','pushbutton','String','Reset', ...
    'Units','normalized','Position',[0.69 y 0.27 0.05],'Callback',@resetZoom,'FontSize',8);
y=y-0.04;

% Pan hint label
uicontrol(hLeft,'Style','text','String','Right-click+drag to pan', ...
    'Units','normalized','Position',[0.05 y 0.9 0.03],'HorizontalAlignment','center', ...
    'FontSize',7,'ForegroundColor',[0.4 0.4 0.4]);
y=y-0.04;

% ── Undo and Clear side by side ──
uicontrol(hLeft,'Style','pushbutton','String','↩ Undo', ...
    'Units','normalized','Position',[0.05 y 0.42 0.05],'Callback',@undoLast);
uicontrol(hLeft,'Style','pushbutton','String','✕ Clear', ...
    'Units','normalized','Position',[0.53 y 0.42 0.05],'Callback',@clearAll, ...
    'ForegroundColor',[0.8 0 0]);
y=y-0.07;

% Save & Next
uicontrol(hLeft,'Style','pushbutton','String','💾 Save & Next', ...
    'Units','normalized','Position',[0.05 y 0.9 0.06],'Callback',@saveAndNext, ...
    'BackgroundColor',[0.6 0.9 0.6],'FontWeight','bold','FontSize',11);

%% Enable axes clicking
set(hAx,'ButtonDownFcn',@onAxesButtonDown);
guidata(hFig,S);

%% ================= CALLBACKS =================

    % ── LIVE COUNTER ──
    function updateDotCounter()
        S = guidata(hFig);
        rings = {'R1','R2','R3'};
        quads = {'ST','SN','IT','IN'};
        g = S.currentGroup;
        ringTotals = zeros(1,3);
        for ri = 1:3
            for qi = 1:4
                ringTotals(ri) = ringTotals(ri) + ...
                    size(S.markings.(g).(rings{ri}).(quads{qi}), 1);
            end
        end
        switch g
            case 'G1', fg=[0.7 0.5 0];  bg=[0.99 0.99 0.92];
            case 'G2', fg=[0 0.5 0.5];  bg=[0.92 0.99 0.99];
            case 'G3', fg=[0.5 0 0.5];  bg=[0.99 0.92 0.99];
        end
        set(hDotCounter, ...
            'String',          sprintf('%s – R1:%d  R2:%d  R3:%d', g, ringTotals(1), ringTotals(2), ringTotals(3)), ...
            'ForegroundColor', fg, ...
            'BackgroundColor', bg);
    end

    % ── BRIGHTNESS / CONTRAST ──
    function onEnhance(~,~)
        S = guidata(hFig);
        if isempty(S.imgOrig), return; end
        factor = get(hEnhanceSlider,'Value');
        img = double(S.imgOrig) * factor;
        img = max(0, min(255, img));
        S.img = uint8(img);
        set(S.hImg,'CData',S.img);
        guidata(hFig,S);
    end

    % ── FIXED CLAHE VESSEL ENHANCEMENT ──
    % Uses the original image every time, so enhancement is reproducible and
    % does not accumulate. This changes DISPLAY ONLY; S.imgOrig remains intact.
    function onCLAHE(~,~)
        S = guidata(hFig);
        if isempty(S.imgOrig), return; end

        orig = S.imgOrig;
        if ndims(orig) == 3
            gray = rgb2gray(orig);
        else
            gray = orig;
        end

        % Normalize input type for adapthisteq while preserving image geometry.
        if ~isa(gray,'uint8') && ~isa(gray,'uint16')
            gray = im2uint8(mat2gray(gray));
        end

        % Fixed parameters: use identically for every image and grader.
        enhanced = adapthisteq(gray, ...
            'NumTiles',[8 8], ...
            'ClipLimit',0.01, ...
            'Distribution','rayleigh');

        % Keep RGB display compatibility when the source image is RGB.
        if ndims(orig) == 3
            enhanced = repmat(enhanced,[1 1 3]);
        end

        S.img = enhanced;
        set(hEnhanceSlider,'Value',1.0);
        set(S.hImg,'CData',S.img);
        guidata(hFig,S);
    end

    function resetImage(~,~)
        S = guidata(hFig);
        if isempty(S.imgOrig), return; end
        set(hEnhanceSlider,'Value',1.0);
        S.img = S.imgOrig;
        set(S.hImg,'CData',S.img);
        guidata(hFig,S);
    end

    % ── ZOOM ──
    function zoomIn(~,~)
        S = guidata(hFig);
        if isempty(S.img), return; end
        S.zoomLevel = S.zoomLevel * 1.25;
        applyZoom(S);
        guidata(hFig,S);
    end

    function zoomOut(~,~)
        S = guidata(hFig);
        if isempty(S.img), return; end
        S.zoomLevel = S.zoomLevel / 1.25;
        applyZoom(S);
        guidata(hFig,S);
    end

    function resetZoom(~,~)
        S = guidata(hFig);
        S.zoomLevel = 1.0;
        xlim(hAx, [0.5, size(S.img,2)+0.5]);
        ylim(hAx, [0.5, size(S.img,1)+0.5]);
        guidata(hFig,S);
    end

    function applyZoom(S)
        xc = mean(xlim(hAx));
        yc = mean(ylim(hAx));
        hw = (size(S.img,2)/2) / S.zoomLevel;
        hh = (size(S.img,1)/2) / S.zoomLevel;
        xlim(hAx, [xc-hw, xc+hw]);
        ylim(hAx, [yc-hh, yc+hh]);
    end

    % ── PAN CALLBACKS ──
    function onAxesButtonDown(~,~)
        S = guidata(hFig);
        if isempty(S.img), return; end

        clickType = get(hFig,'SelectionType');
        if strcmp(clickType,'alt') || strcmp(clickType,'extend')
            % Right-click ('alt') or middle-click ('extend') → start pan
            S.isPanning  = true;
            cp           = get(hAx,'CurrentPoint');
            S.panStartPt = [cp(1,1), cp(1,2)];
            set(hFig,'Pointer','fleur');
            set(hFig,'WindowButtonMotionFcn', @onPanMotion);
            set(hFig,'WindowButtonUpFcn',     @onPanEnd);
            guidata(hFig,S);
        else
            % Left-click → pass through to marker placement
            onAxesClick([],[]);
        end
    end

    function onPanMotion(~,~)
        S = guidata(hFig);
        if ~S.isPanning, return; end
        cp = get(hAx,'CurrentPoint');
        dx = S.panStartPt(1) - cp(1,1);
        dy = S.panStartPt(2) - cp(1,2);
        xl = xlim(hAx);
        yl = ylim(hAx);

        % Clamp to image boundaries
        imgW  = size(S.img,2);
        imgH  = size(S.img,1);
        newXl = xl + dx;
        newYl = yl + dy;
        newXl = [max(0.5, newXl(1)),  min(imgW+0.5, newXl(2))];
        newYl = [max(0.5, newYl(1)),  min(imgH+0.5, newYl(2))];

        xlim(hAx, newXl);
        ylim(hAx, newYl);
        % Incremental delta: update anchor each frame for smooth motion
        S.panStartPt = [cp(1,1), cp(1,2)];
        guidata(hFig,S);
    end

    function onPanEnd(~,~)
        S = guidata(hFig);
        S.isPanning = false;
        set(hFig,'Pointer','arrow');
        set(hFig,'WindowButtonMotionFcn','');
        set(hFig,'WindowButtonUpFcn','');
        guidata(hFig,S);
    end

    function onStudyID(h,~)
        S=guidata(hFig); S.studyID=strtrim(h.String); guidata(hFig,S);
    end

    function onUploadFolder(~,~)
        folder = uigetdir('','Select folder containing images');
        if isequal(folder,0), return; end
        S = guidata(hFig);
        S.folderPath = folder;
        S.annotatedFolder = fullfile(folder,'annotated_images');
        if ~exist(S.annotatedFolder,'dir'), mkdir(S.annotatedFolder); end
        % ROI crops (128×128 patches — optional visual QC)
        S.roiFolder = fullfile(S.annotatedFolder,'ROI_crops');
        if ~exist(S.roiFolder,'dir'), mkdir(S.roiFolder); end
        % Clean original TIFFs for model training (no overlays)
        S.trainingFolder = fullfile(S.annotatedFolder,'training_images');
        if ~exist(S.trainingFolder,'dir'), mkdir(S.trainingFolder); end
        imgFiles = [dir(fullfile(folder,'*.jpg'));
                    dir(fullfile(folder,'*.jpeg'));
                    dir(fullfile(folder,'*.png'));
                    dir(fullfile(folder,'*.tif'));
                    dir(fullfile(folder,'*.tiff'))];
        S.imageFiles = {imgFiles.name};
        if isempty(S.imageFiles)
            errordlg('No images found in folder','Error'); return;
        end
        S.currentImageIdx = 1;
        guidata(hFig,S);
        loadCurrentImage();
        updateImageCounter();
    end

    function loadCurrentImage()
        S = guidata(hFig);
        if isempty(S.imageFiles) || S.currentImageIdx < 1, return; end
        cla(hAx);
        imgPath = fullfile(S.folderPath, S.imageFiles{S.currentImageIdx});
        S.img  = imread(imgPath);
        % Fix EXIF orientation
        try
            info = imfinfo(imgPath);
            if isfield(info,'Orientation')
                switch info.Orientation
                    case 6, S.img = rot90(S.img,3);
                    case 8, S.img = rot90(S.img,1);
                    case 3, S.img = rot90(S.img,2);
                end
            end
        catch, end
        S.imgOrig = S.img;   % store original for brightness/contrast reset
        % Reset sliders
        set(hEnhanceSlider,'Value',1.0);
        S.hImg = imshow(S.img,'Parent',hAx);
        hold(hAx,'on'); axis(hAx,'image','off');
        xlim(hAx,[0.5, size(S.img,2)+0.5]);
        ylim(hAx,[0.5, size(S.img,1)+0.5]);
        S.zoomLevel  = 1.0;
        S.isPanning  = false;
        S.panStartPt = [];
        set(S.hImg,'PickableParts','all','HitTest','on','ButtonDownFcn',@onAxesButtonDown);
        % Reset annotations
        S.ON=[]; S.F=[]; S.R1=[]; S.R2=[]; S.R3=[];
        S.hR1=[]; S.hR2=[]; S.hR3=[]; S.hON=[]; S.hF=[]; S.hQuadLines=[];
        S.hAllMarks=[]; S.temporalSign=1;
        % ── AUTO-LOAD PRE-ESTABLISHED RINGS ──
        [~,fname,~] = fileparts(S.imageFiles{S.currentImageIdx});
        ringsPath = fullfile(S.annotatedFolder, sprintf('%s_rings.mat', fname));
        if exist(ringsPath,'file')
            try
                loaded = load(ringsPath,'rings');
                r = loaded.rings;
                S.ON = r.ON;  S.F = r.F;
                S.R1 = r.R1; S.R2 = r.R2; S.R3 = r.R3;
                S.eyeSide      = r.eyeSide;
                S.temporalSign = r.temporalSign;
                guidata(hFig,S);
                generateRingsAndQuadrants([],[]);
                S = guidata(hFig);
            catch ME
                warndlg(sprintf('Could not load rings for %s:\n%s', fname, ME.message), ...
                        'Ring Load Error');
            end
        else
            warndlg(sprintf('No rings file found for:\n%s\n\nAsk coordinator to run Ring Generator first.', fname), ...
                    'Rings Not Ready');
        end
        emptyQ=struct('ST',[],'SN',[],'IT',[],'IN',[]);
        emptyR=struct('R1',emptyQ,'R2',emptyQ,'R3',emptyQ);
        S.markings=struct('G1',emptyR,'G2',emptyR,'G3',emptyR);
        % Auto study ID and eye side
        [~,fname,~] = fileparts(S.imageFiles{S.currentImageIdx});
        S.studyID = fname;
        set(hStudyIDEdit,'String',fname);
        fnUpper = upper(fname);
        if contains(fnUpper,'_OS') || contains(fnUpper,' OS') || endsWith(fnUpper,'OS')
            S.eyeSide = 'OS';
        else
            S.eyeSide = 'OD';
        end
        % Try to resume from existing .mat
        matPath = fullfile(S.annotatedFolder, sprintf('%s_annotations.mat',fname));
        if exist(matPath,'file')
            try
                loaded = load(matPath,'annotations');
                ann = loaded.annotations;
                S.ON = ann.ON; S.F = ann.F;
                S.R1 = ann.R1; S.R2 = ann.R2; S.R3 = ann.R3;
                S.markings = ann.markings;
                S.eyeSide  = ann.eyeSide;
                guidata(hFig,S);
                generateRingsAndQuadrants([],[]);
                S = guidata(hFig);
                redrawAll();
                S = guidata(hFig);
                msgbox(sprintf('Resumed previous session for %s',fname),'Session Loaded');
            catch
            end
        end
        guidata(hFig,S);
        updateModeLabel('None');
        updateDotCounter();
    end

    function tf = endsWith(str,suffix)
        tf = length(str)>=length(suffix) && strcmp(str(end-length(suffix)+1:end),suffix);
    end

    % ── IMAGE COUNTER WITH GRADED INDICATOR ──
    function updateImageCounter()
        S=guidata(hFig);
        if ~isempty(S.imageFiles)
            [~,fname,~] = fileparts(S.imageFiles{S.currentImageIdx});
            matPath = fullfile(S.annotatedFolder, sprintf('%s_annotations.mat',fname));
            if exist(matPath,'file')
                tag = ' ✓';
            else
                tag = '';
            end
            set(hImageCounter,'String', ...
                sprintf('Image %d of %d%s', S.currentImageIdx, length(S.imageFiles), tag));
        else
            set(hImageCounter,'String','No images loaded');
        end
    end

    function onNext(~,~)
        S=guidata(hFig);
        if S.currentImageIdx < length(S.imageFiles)
            S.currentImageIdx=S.currentImageIdx+1;
            guidata(hFig,S); loadCurrentImage(); updateImageCounter();
        else
            msgbox('You have reached the last image!','Info');
        end
    end

    function onPrevious(~,~)
        S=guidata(hFig);
        if S.currentImageIdx > 1
            S.currentImageIdx=S.currentImageIdx-1;
            guidata(hFig,S); loadCurrentImage(); updateImageCounter();
        else
            msgbox('You are at the first image!','Info');
        end
    end

    function setMode(m)
        S=guidata(hFig); S.clickMode=m; guidata(hFig,S);
        updateModeLabel(m);
    end

    function updateModeLabel(m)
        set(hModeLabel,'String',sprintf('Mode: %s',m));
    end

    function setGroup(src,g)
        S=guidata(hFig);
        set([hG1btn hG2btn hG3btn],'Value',0); set(src,'Value',1);
        S.currentGroup=g; guidata(hFig,S);
        updateDotCounter();
    end

    function generateRingsAndQuadrants(~,~)
        S=guidata(hFig);
        if isempty(S.ON)||isempty(S.F)
            errordlg('Please set Optic Nerve (ON) and Fovea (F) first.','Missing Points'); return;
        end
        d=hypot(S.F(1)-S.ON(1),S.F(2)-S.ON(2));
        S.R1=2*d; S.R2=3*d; S.R3=4*d;
        t=linspace(0,2*pi,400);
        S.temporalSign = sign(S.F(1) - S.ON(1));
        if S.temporalSign == 0, S.temporalSign = 1; end
        delete([S.hR1 S.hR2 S.hR3]);
        delete(S.hQuadLines(ishandle(S.hQuadLines))); S.hQuadLines=[];
        S.hR1=plot(hAx,S.ON(1)+S.R1*cos(t),S.ON(2)+S.R1*sin(t),'w-','LineWidth',1.5);
        S.hR2=plot(hAx,S.ON(1)+S.R2*cos(t),S.ON(2)+S.R2*sin(t),'w--','LineWidth',1.5);
        S.hR3=plot(hAx,S.ON(1)+S.R3*cos(t),S.ON(2)+S.R3*sin(t),'y--','LineWidth',1.5);
        ext=S.R3*1.05;
        h1=plot(hAx,[S.ON(1)-ext S.ON(1)+ext],[S.ON(2) S.ON(2)],'w-','LineWidth',0.8);
        h2=plot(hAx,[S.ON(1) S.ON(1)],[S.ON(2)-ext S.ON(2)+ext],'w-','LineWidth',0.8);
        S.hQuadLines=[h1 h2];
        r_lbl=S.R3*0.78; ts=S.temporalSign;
        text(S.ON(1)+r_lbl*ts*0.6, S.ON(2)-r_lbl*0.6,'ST','Color','w','FontWeight','bold','FontSize',13,'HorizontalAlignment','center','Parent',hAx);
        text(S.ON(1)-r_lbl*ts*0.6, S.ON(2)-r_lbl*0.6,'SN','Color','w','FontWeight','bold','FontSize',13,'HorizontalAlignment','center','Parent',hAx);
        text(S.ON(1)+r_lbl*ts*0.6, S.ON(2)+r_lbl*0.6,'IT','Color','w','FontWeight','bold','FontSize',13,'HorizontalAlignment','center','Parent',hAx);
        text(S.ON(1)-r_lbl*ts*0.6, S.ON(2)+r_lbl*0.6,'IN','Color','w','FontWeight','bold','FontSize',13,'HorizontalAlignment','center','Parent',hAx);
        text(S.ON(1)+ts*(S.R1+5), S.ON(2)+8,'R1','Color','w','FontSize',9,'Parent',hAx);
        text(S.ON(1)+ts*(S.R2+5), S.ON(2)+8,'R2','Color','w','FontSize',9,'Parent',hAx);
        text(S.ON(1)+ts*(S.R3+5), S.ON(2)+8,'R3','Color','y','FontSize',9,'Parent',hAx);
        uistack(S.hR1,'top'); uistack(S.hR2,'top'); uistack(S.hR3,'top');
        xlim(hAx,[0.5, size(S.img,2)+0.5]);
        ylim(hAx,[0.5, size(S.img,1)+0.5]);
        guidata(hFig,S);
    end

    function q = getQuadrant(x,y,ON,temporalSign)
        isAbove    = (y < ON(2));
        isTemporal = ((x - ON(1)) * temporalSign > 0);
        if     isAbove &&  isTemporal, q='ST';
        elseif isAbove && ~isTemporal, q='SN';
        elseif ~isAbove && isTemporal, q='IT';
        else,                          q='IN';
        end
    end

    function onAxesClick(~,~)
        S=guidata(hFig);
        if isempty(S.clickMode)||strcmp(S.clickMode,'None'), return; end
        cp=get(hAx,'CurrentPoint');
        x=cp(1,1); y=cp(1,2);
        switch S.clickMode
            case 'ON'
                % Grader version: block ON/F changes
                warndlg('Landmarks are locked in this version.','Locked');
                return;
            case 'F'
                % Grader version: block ON/F changes
                warndlg('Landmarks are locked in this version.','Locked');
                return;
            otherwise
                if isempty(S.ON)||isempty(S.R1)
                    warndlg('Generate rings first!','Rings Missing');
                    guidata(hFig,S); return;
                end
                ring = S.clickMode;
                g    = S.currentGroup;
                cx   = x;  cy = y;                        % raw click coords
                dClick = hypot(cx-S.ON(1), cy-S.ON(2));

                % ── Determine target ring radius and acceptance tolerance ──
                % Accept clicks within ±20 % of the ring radius (R1) or
                % ±50 % of the inter-ring gap (R2, R3) so the grader does
                % not need pixel-perfect accuracy.
                switch ring
                    case 'R1', targetR = S.R1; tol = S.R1          * 0.20;
                    case 'R2', targetR = S.R2; tol = (S.R2-S.R1)   * 0.50;
                    case 'R3', targetR = S.R3; tol = (S.R3-S.R2)   * 0.50;
                end
                inBand = abs(dClick - targetR) <= tol;

                if ~inBand
                    set(hModeLabel,'String',sprintf('Mode: %s  ← click closer to ring!',ring),'ForegroundColor',[1 0 0]);
                    pause(0.25);
                    set(hModeLabel,'String',sprintf('Mode: %s',ring),'ForegroundColor',[0.8 0 0]);
                    guidata(hFig,S); return;
                end

                % ── Snap dot to exact ring boundary ──
                % Project the click angle onto the circle so the marker
                % sits exactly ON the ring at the vessel-crossing position.
                theta = atan2(cy - S.ON(2), cx - S.ON(1));
                x = S.ON(1) + targetR * cos(theta);
                y = S.ON(2) + targetR * sin(theta);

                q = getQuadrant(x, y, S.ON, S.temporalSign);
                S.markings.(g).(ring).(q)(end+1,:) = [x y];
                switch ring
                    case 'R1', col='y';
                    case 'R2', col='c';
                    case 'R3', col='m';
                end
                S.hAllMarks(end+1)=plot(hAx,x,y,'o', ...
                    'MarkerFaceColor',col,'MarkerEdgeColor','k','MarkerSize',4,'LineWidth',0.5);
        end
        guidata(hFig,S);
        updateDotCounter();
    end

    function clearAll(~,~)
        S=guidata(hFig);
        emptyQ=struct('ST',[],'SN',[],'IT',[],'IN',[]);
        emptyR=struct('R1',emptyQ,'R2',emptyQ,'R3',emptyQ);
        S.markings=struct('G1',emptyR,'G2',emptyR,'G3',emptyR);
        delete(S.hAllMarks(ishandle(S.hAllMarks))); S.hAllMarks=[];
        guidata(hFig,S);
        updateDotCounter();
    end

    function undoLast(~,~)
        S=guidata(hFig); g=S.currentGroup;
        rings={'R3','R2','R1'}; quads={'IN','IT','SN','ST'};
        removed=false;
        for ri=1:3
            if removed, break; end
            for qi=1:4
                pts=S.markings.(g).(rings{ri}).(quads{qi});
                if ~isempty(pts)
                    S.markings.(g).(rings{ri}).(quads{qi})(end,:)=[];
                    removed=true; break;
                end
            end
        end
        delete(S.hAllMarks(ishandle(S.hAllMarks))); S.hAllMarks=[];
        guidata(hFig,S);
        redrawAll();
        updateDotCounter();
    end

    function redrawAll()
        S=guidata(hFig);
        rings={'R1','R2','R3'}; cols={'y','c','m'};
        quads={'ST','SN','IT','IN'};
        for gi=1:3
            g=sprintf('G%d',gi);
            for ri=1:3
                for qi=1:4
                    pts=S.markings.(g).(rings{ri}).(quads{qi});
                    for pi=1:size(pts,1)
                        S.hAllMarks(end+1)=plot(hAx,pts(pi,1),pts(pi,2),'o', ...
                            'MarkerFaceColor',cols{ri},'MarkerEdgeColor','k', ...
                            'MarkerSize',4,'LineWidth',0.5);
                    end
                end
            end
        end
        guidata(hFig,S);
    end

    function saveAndNext(~,~)
        S=guidata(hFig);
        if isempty(S.studyID)
            errordlg('Enter Study ID','Error'); return;
        end
        rings={'R1','R2','R3'}; quads={'ST','SN','IT','IN'};
        groups={'G1','G2','G3'};
        varNames={'StudyID','EyeSide'};
        vals={S.studyID, S.eyeSide};
        for gi=1:3
            g=groups{gi};
            for ri=1:3
                rn=rings{ri};
                rowTot=0;
                for qi=1:4
                    qn=quads{qi};
                    cnt=size(S.markings.(g).(rn).(qn),1);
                    varNames{end+1}=sprintf('%s_%s_%s',g,rn,qn);
                    vals{end+1}=cnt;
                    rowTot=rowTot+cnt;
                end
                varNames{end+1}=sprintf('%s_%s_Total',g,rn);
                vals{end+1}=rowTot;
            end
        end
        newRow=cell2table(vals,'VariableNames',varNames);
        file = fullfile(S.folderPath, 'RML_results_v4_Feb2026.xlsx');
        try
            if exist(file,'file')
                existing = readtable(file);
                % ── DUPLICATE ROW WARNING ──
                if any(strcmp(existing.StudyID, S.studyID))
                    answer = questdlg( ...
                        sprintf('"%s" already exists in Excel.\nOverwrite or keep both?', S.studyID), ...
                        'Duplicate Entry','Overwrite','Keep Both','Keep Both');
                    if strcmp(answer,'Overwrite')
                        existing(strcmp(existing.StudyID, S.studyID),:) = [];
                    end
                end
                T = [existing; newRow];
            else
                T = newRow;
            end
            writetable(T,file,'WriteMode','overwrite');
            msgbox(sprintf('Saved to:\n%s',file),'Save Successful');
        catch ME
            disp(['Excel save error: ' ME.message]);
            csvFile = fullfile(S.folderPath, 'RML_results_v4_Feb2026.csv');
            try
                if exist(csvFile,'file')
                    try existing=readtable(csvFile); T=[existing;newRow]; catch, T=newRow; end
                else, T=newRow; end
                writetable(T,csvFile);
                msgbox(sprintf('Saved to %s (Excel unavailable)',csvFile),'Info');
            catch err
                errordlg(sprintf('Save failed: %s',err.message),'Error'); return;
            end
        end

        % ═══════════════════════════════════════════════════════════
        % SAVE BLOCK
        % ─────────────────────────────────────────────────────────
        % Produces three outputs:
        %
        %  1. {studyID}_annotated.tiff  – QC image WITH rings/dots overlaid
        %                                 (for review, NOT for model training)
        %
        %  2. training_images/{studyID}_train.tiff
        %                               – CLEAN original image, no overlays.
        %                                 This is what the model trains on.
        %
        %  3. ROI_coords.csv            – one row per vessel crossing with
        %                                 pixel + YOLO coordinates referencing
        %                                 the clean training TIFF.
        % ═══════════════════════════════════════════════════════════
        try
            % ── 1. Annotated QC image (full image, zoom/pan independent) ──
            oldXL = xlim(hAx);
            oldYL = ylim(hAx);
            xlim(hAx, [0.5, size(S.img,2)+0.5]);
            ylim(hAx, [0.5, size(S.img,1)+0.5]);
            drawnow;
            exportgraphics(hAx, ...
                fullfile(S.annotatedFolder, sprintf('%s_annotated.tiff', S.studyID)), ...
                'Resolution',300);
            xlim(hAx, oldXL);
            ylim(hAx, oldYL);

            % ── 2. Clean training TIFF (S.imgOrig — zero overlays) ──
            trainImgName = sprintf('%s_train.tiff', S.studyID);
            trainImgPath = fullfile(S.trainingFolder, trainImgName);
            imwrite(S.imgOrig, trainImgPath);   % lossless, original pixel values

            % ── 3. .mat session file ──
            annotations = struct('studyID',S.studyID,'ON',S.ON,'F',S.F, ...
                'R1',S.R1,'R2',S.R2,'R3',S.R3,'markings',S.markings,'eyeSide',S.eyeSide);
            save(fullfile(S.annotatedFolder, sprintf('%s_annotations.mat',S.studyID)), 'annotations');

            % ── 4. ROI_coords.csv — one row per vessel crossing ──
            % Columns:
            %   train_img_filename – clean TIFF the model trains on
            %   studyID, eye_side, group, ring, quadrant, dot_n
            %   center_x, center_y         – crossing location (original px)
            %   orig_img_w, orig_img_h     – full image dimensions
            %   yolo_cx, yolo_cy           – center normalised 0-1
            %   yolo_w,  yolo_h            – fixed detection box normalised 0-1
            %                                (box = 2*roiSize × 2*roiSize px)
            if ~isempty(S.trainingFolder) && ~isempty(S.imgOrig)
                [imgH, imgW, ~] = size(S.imgOrig);
                ringsROI = {'R1','R2','R3'};
                quadsROI = {'ST','SN','IT','IN'};
                coordRows = {};

                % Fixed normalised box size (same for every crossing)
                boxW_norm = (2 * S.roiSize) / imgW;
                boxH_norm = (2 * S.roiSize) / imgH;

                for gi2 = 1:3
                    gROI = sprintf('G%d', gi2);
                    for ri2 = 1:3
                        rnROI = ringsROI{ri2};
                        for qi2 = 1:4
                            qnROI = quadsROI{qi2};
                            pts = S.markings.(gROI).(rnROI).(qnROI);
                            for pi2 = 1:size(pts,1)
                                cx = pts(pi2,1);
                                cy = pts(pi2,2);
                                coordRows{end+1} = { ...
                                    trainImgName, ...   % which clean image to use
                                    S.studyID, S.eyeSide, ...
                                    gROI, rnROI, qnROI, pi2, ...
                                    cx, cy, ...
                                    imgW, imgH, ...
                                    cx/imgW, cy/imgH, ...   % yolo_cx, yolo_cy
                                    boxW_norm, boxH_norm};  % yolo_w,  yolo_h
                            end
                        end
                    end
                end

                if ~isempty(coordRows)
                    coordFile = fullfile(S.roiFolder, 'ROI_coords.csv');
                    colNames  = {'train_img_filename','studyID','eye_side', ...
                                 'group','ring','quadrant','dot_n', ...
                                 'center_x','center_y', ...
                                 'orig_img_w','orig_img_h', ...
                                 'yolo_cx','yolo_cy','yolo_w','yolo_h'};
                    newT = cell2table(vertcat(coordRows{:}), 'VariableNames', colNames);
                    if exist(coordFile,'file')
                        try
                            existingCoords = readtable(coordFile, 'TextType','string');
                            existingCoords(strcmp(existingCoords.studyID, S.studyID),:) = [];
                            newT = [existingCoords; newT];
                        catch
                            % corrupt file → overwrite cleanly
                        end
                    end
                    writetable(newT, coordFile);
                end
            end

        catch err
            warning('Save failed: %s', err.message);
            msgbox(err.message,'Save Error');
        end

        % Auto-advance
        if S.currentImageIdx < length(S.imageFiles)
            S.currentImageIdx=S.currentImageIdx+1;
            guidata(hFig,S); loadCurrentImage(); updateImageCounter();
        else
            msgbox('All images completed!','Done');
        end
    end

    % =========================================================
    % ── ROI CROP HELPER ──
    % Saves a (2*roiSize)×(2*roiSize) px patch from imgOrig centred on
    % the vessel-crossing point (x,y).  Clamps to image borders.
    %
    % Returns:
    %   fname        – PNG filename (not full path)
    %   x1,y1,x2,y2 – actual bounding box used (1-based, clamped pixels)
    %                  in original image space — use these for ML labels.
    % =========================================================
    function [fname, x1, y1, x2, y2] = saveROICrop(img, x, y, studyID, g, ring, quad, n, roiFolder, roiSize)
        xi = round(x);   yi = round(y);
        [H, W, ~] = size(img);
        x1 = max(1, xi - roiSize);   x2 = min(W, xi + roiSize);
        y1 = max(1, yi - roiSize);   y2 = min(H, yi + roiSize);
        crop = img(y1:y2, x1:x2, :);
        fname = sprintf('%s_%s_%s_%s_%02d_ROI.png', studyID, g, ring, quad, n);
        imwrite(crop, fullfile(roiFolder, fname));
    end

end  % rml_lab_gui_v4