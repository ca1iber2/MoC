function [time, amplitude]=velocityinterp(time,amplitude,inc)
%This function is a simple interpolation in a velocity trace to create more
%points for a more dense mesh
timeSet = [min(time):inc:max(time)];
velocity = interp1(time, amplitude, timeSet);
velocity = velocity';
time = timeSet';
amplitude = velocity;