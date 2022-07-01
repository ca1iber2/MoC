clc
clear
close all

%Input excel sheet names for velocity
%input as 'filename.xlsx'
%units should be kilometers/sec & nanoseconds
velocity = {'s88773.xlsx'};
%velocity = {'s98392.xlsx'};

%Input ecxel sheet names for EOS data
%Utilize template for EOS formatting
%Layers should be listed so the window material is second if velocity data comes from interface
EOS_data = {'Fe_LiF.xlsx' 'MgO EOS.xlsx'};
%EOS_data = {'Bradley_calculated.xlsx'};
%EOS_data = {'Fe EOS.xlsx' 'Bradley_extrapolate2.xlsx'};


%Input sample length
%Units should be microns
%Layers should be listed so the window material is second if velocity data comes from interface
xo = {3.23 100};
%xo = 111.5;
%xo = {15 100};

%If you are assuming your entire sample stack is 1 material, enter your
%sample thickness and window thickness
%else just leave both as 0
stack = 0; %12
window = 0; %60

%Determine if velocity profile is free surface or interface data
interface = true;
%Determine if CL needs to be calculated for EOS data, true is yes 
%(CL =(rho/rho_o)* CS, CS = sqrt(dp/drho))
soundSpeed = true;
%Determine if velocity data needs smoothing
smoothing = false;
%Determine if velocity data needs interpolation
%This can be useful if your velocity trace does not have many data points
%If you do want interpolation, also input the query amount
velinterp = true;
inc = 0.05;

%X-ray pulse time
xray = {0 0};

%Input the velocity profile data
opts = detectImportOptions(velocity{1}); 
FS = readtable(velocity{1}, opts); 

%Smoothing code using method sgolay
if smoothing == true
    FS.amplitude = smoothdata(FS.amplitude, 'sgolay');
end

%Interpolating velocity
if velinterp == true
    [fstime, fsamplitude] = velocityinterp(FS.time, FS.amplitude, inc);
else
    fstime = FS.time;
    fsamplitude = FS.amplitude;
end
    

if interface == true %This is the interface code
    numLayers = 2;
   
    
    %Input EOS data for each layer
    %EOS should have the headers P, CL, Rho_data, Rho_o, xo in excel
    for n = 1:numLayers
        opts2 = detectImportOptions(EOS_data{n});
        Sample{n} = readtable(EOS_data{n}, opts2);
        Rho_o{n} = Sample{n}.Rho_o(1);
    end
    
    %Calculate CL if needed
    if soundSpeed == true
        for n = 1:numLayers
            [Sample{n}.CL, Sample{n}.CS]=EOS(Sample{n}.Rho, Sample{n}.P, Rho_o{n}(1,1));
        end
    end
    
    %Get other EOS parameters
    for n = 1:numLayers
        [Sample{n}.Press, Sample{n}.Sigma, Sample{n}.Rho]=Get_PSR(Sample{n}.P, Sample{n}.CL, Sample{n}.Rho, Rho_o{n}(1,1));
    end 

    %From the free surface velocity, calculate forwards and backwards characteristics
    [F1,B1,F2,B2] = BCSI(Sample{1}.Press, Sample{2}.Press, Sample{1}.Sigma, Sample{2}.Sigma, fsamplitude);
    
    %Now that we know F and B.  Lets find Up, Sigma, H and T for all
    %intersections
    [H,Time,Tapplied,U1,S1] = MBC(F1,B1,xo{1},Sample{1}.Sigma,Sample{1}.CL,fstime);

    %Calculate interface insitu values, this is only for multilayer use
    [InTime, InVelocity, InSigma] = MBC_Int(H, U1, S1, Tapplied, Time, xo); 
    InPress = interp1(Sample{1}.Sigma, Sample{1}.Press, InVelocity);

    
else %This is the free surface code
    %Import EOS data
    %EOS should have the headers P, CL, Rho_data, Rho_o, xo in excel
    opts2 = detectImportOptions(EOS_data{1});
    Sample = readtable(EOS_data{1}, opts2);
    Rho_o = Sample.Rho_o(1);
    
    %Calculate CL
    if soundSpeed == true
        [Sample.CL, Sample.CS]=EOS(Sample.Rho, Sample.P, Rho_o);
    end
    
    %Get other EOS parameters
    [Sample.Press,Sample.Sigma,Sample.Rho]=Get_PSR(Sample.P,Sample.CL,Sample.Rho, Rho_o);

    %From the free surface velocity, calculate forwards and backwards characteristics
    [F1,B1] = BCSF(fsamplitude);
    
    %Now that we know F and B.  Lets find Up, Sigma, H and T for all
    %intersections
    [H,Time,Tapplied,U1,S1] = MBC(F1,B1,xo,Sample.Sigma,Sample.CL,fstime);

    %Calculate interface insitu values, this is only for multilayer use
    [InTime, InVelocity, InSigma] = MBC_Int(H, U1, S1, Tapplied, Time, xo); 
    InPress = interp1(Sample.Sigma, Sample.Press, InVelocity);
    
    %line calculations for plotting
    horzline1 = xo - window;
    horzline2 = xo - stack - window;

end


%Plotting Up
Characteristics(H,Time,H(:,1)*0,Tapplied,1,1,U1,'Up');
yline(xray{1});
yline(xray{2});
if interface == false
    xline(horzline1);
    xline(horzline2);
    xline(xo);
end

%Interpolate for pressure at each point using sigma
if interface == true
    P1 = interp1(Sample{1}.Sigma,Sample{1}.Press,S1);
else
    P1 = interp1(Sample.Sigma,Sample.Press,S1);
end

%Plotting pressure
Characteristics(H,Time,H(:,1)*0,Tapplied,1,2,P1,'Pressure (GPa)');
yline(xray{1});
yline(xray{2});
if interface == false
    xline(horzline1);
    xline(horzline2);
    xline(xo);
end

