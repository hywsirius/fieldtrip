function [type] = ft_filetype(filename, desired, varargin)

% FT_FILETYPE determines the filetype of many EEG/MEG/MRI data files by
% looking at the name, extension and optionally (part of) its contents.
% It tries to determine the global type of file (which usually
% corresponds to the manufacturer, the recording system or to the
% software used to create the file) and the particular subtype (e.g.
% continuous, average).
%
% Use as
%   type = ft_filetype(filename)
%   type = ft_filetype(dirname)
%
% This gives you a descriptive string with the data type, and can be
% used in a switch-statement. The descriptive string that is returned
% usually is something like 'XXX_YYY'/ where XXX refers to the
% manufacturer and YYY to the type of the data.
%
% Alternatively, use as
%   flag = ft_filetype(filename, type)
%   flag = ft_filetype(dirname, type)
% This gives you a boolean flag (0 or 1) indicating whether the file
% is of the desired type, and can be used to check whether the
% user-supplied file is what your subsequent code expects.
%
% Alternatively, use as
%   flag = ft_filetype(dirlist, type)
% where the dirlist contains a list of files contained within one
% directory. This gives you a boolean vector indicating for each file
% whether it is of the desired type.
%
% Most filetypes of the following manufacturers and/or software programs are recognized
%  - 4D/BTi
%  - AFNI
%  - ASA
%  - Analyse
%  - Analyze/SPM
%  - BESA
%  - BrainVision
%  - Curry
%  - Dataq
%  - EDF
%  - EEProbe
%  - Elektra/Neuromag
%  - LORETA
%  - FreeSurfer
%  - MINC
%  - Neuralynx
%  - Neuroscan
%  - Plexon
%  - SR Research Eyelink
%  - Tucker Davis Technology
%  - VSM-Medtech/CTF
%  - Yokogawa
%  - nifti, gifti
%  - Localite
%  - Stanford *.ply

% Copyright (C) 2003-2013 Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% these are for remembering the type on subsequent calls with the same input arguments
persistent previous_argin previous_argout previous_pwd

if nargin<2
  % ensure that all input arguments are defined
  desired = [];
end

current_argin = {filename, desired, varargin{:}};
current_pwd   = pwd;
if isequal(current_argin, previous_argin) && isequal(current_pwd, previous_pwd)
  % don't do the detection again, but return the previous value from cache
  type = previous_argout{1};
  return
end

if isa(filename, 'memmapfile')
  filename = filename.Filename;
end

% % get the optional arguments
% checkheader = ft_getopt(varargin, 'checkheader', true);
%
% if ~checkheader
%   % assume that the header is always ok, e.g when the file does not yet exist
%   % this replaces the normal function with a function that always returns true
%   filetype_check_header = @filetype_true;
% end

if iscell(filename)
  if ~isempty(desired)
    % perform the test for each filename, return a boolean vector
    type = false(size(filename));
  else
    % return a string with the type for each filename
    type = cell(size(filename));
  end
  for i=1:length(filename)
    if strcmp(filename{i}(end), '.')
      % do not recurse into this directory or the parent directory
      continue
    else
      if iscell(type)
        type{i} = ft_filetype(filename{i}, desired);
      else
        type(i) = ft_filetype(filename{i}, desired);
      end
    end
  end
  return
end

% start with unknown values
type         = 'unknown';
manufacturer = 'unknown';
content      = 'unknown';

if isempty(filename)
  if isempty(desired)
    % return the "unknown" outputs
    return
  else
    % return that it is a non-match
    type = false;
    return
  end
end

% the parts of the filename are used further down
[p, f, x] = fileparts(filename);

% prevent this test if the filename resembles an URI, i.e. like "scheme://"
if isempty(strfind(filename , '://')) && isdir(filename)
  % the directory listing is needed below
  ls = dir(filename);
  % remove the parent directory and the directory itself from the list
  ls = ls(~strcmp({ls.name}, '.'));
  ls = ls(~strcmp({ls.name}, '..'));
  for i=1:length(ls)
    % make sure that the directory listing includes the complete path
    ls(i).name = fullfile(filename, ls(i).name);
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% start determining the filetype
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% this checks for a compressed file (of arbitrary type)
if filetype_check_extension(filename, 'zip')...
    || (filetype_check_extension(filename, '.gz') && ~filetype_check_extension(filename, '.nii.gz'))...
    || filetype_check_extension(filename,  'tgz')...
    || filetype_check_extension(filename, 'tar')
  
  type         = 'compressed';
  manufacturer = 'undefined';
  content      = 'unknown, extract first';
  
  % these are some streams for asynchronous BCI
elseif filetype_check_uri(filename, 'fifo')
  type        = 'fcdc_fifo';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'stream';
elseif filetype_check_uri(filename, 'buffer')
  type        = 'fcdc_buffer';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'stream';
elseif filetype_check_uri(filename, 'mysql')
  type        = 'fcdc_mysql';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'stream';
elseif filetype_check_uri(filename, 'tcp')
  type        = 'fcdc_tcp';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'stream';
elseif filetype_check_uri(filename, 'udp')
  type        = 'fcdc_udp';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'stream';
elseif filetype_check_uri(filename, 'rfb')
  type        = 'fcdc_rfb';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'stream';
elseif filetype_check_uri(filename, 'serial')
  type        = 'fcdc_serial';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'stream';
elseif filetype_check_uri(filename, 'global')
  type        = 'fcdc_global';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = 'global variable';
elseif filetype_check_uri(filename, 'shm')
  type        = 'ctf_shm';
  manufacturer = 'CTF';
  content      = 'real-time shared memory buffer';
elseif filetype_check_uri(filename, 'empty')
  type        = 'empty';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content      = '/dev/null';
  
  % known CTF file types
elseif isdir(filename) && filetype_check_extension(filename, '.ds') && exist(fullfile(filename, [f '.res4']))
  type = 'ctf_ds';
  manufacturer = 'CTF';
  content = 'MEG dataset';
elseif isdir(filename) && ~isempty(dir(fullfile(filename, '*.res4'))) && ~isempty(dir(fullfile(filename, '*.meg4')))
  type = 'ctf_ds';
  manufacturer = 'CTF';
  content = 'MEG dataset';
elseif filetype_check_extension(filename, '.res4') && (filetype_check_header(filename, 'MEG41RS') || filetype_check_header(filename, 'MEG42RS') || filetype_check_header(filename, 'MEG4RES') || filetype_check_header(filename, 'MEG3RES')) %'MEG3RES' pertains to ctf64.ds
  type = 'ctf_res4';
  manufacturer = 'CTF';
  content = 'MEG/EEG header information';
elseif filetype_check_extension(filename, '.meg4') && (filetype_check_header(filename, 'MEG41CP') || filetype_check_header(filename, 'MEG4CPT')) %'MEG4CPT' pertains to ctf64.ds
  type = 'ctf_meg4';
  manufacturer = 'CTF';
  content = 'MEG/EEG';
elseif strcmp(f, 'MarkerFile') && filetype_check_extension(filename, '.mrk') && filetype_check_header(filename, 'PATH OF DATASET:')
  type = 'ctf_mrk';
  manufacturer = 'CTF';
  content = 'marker file';
elseif filetype_check_extension(filename, '.mri') && filetype_check_header(filename, 'CTF_MRI_FORMAT VER 2.2')
  type = 'ctf_mri';
  manufacturer = 'CTF';
  content = 'MRI';
elseif filetype_check_extension(filename, '.mri') && filetype_check_header(filename, 'CTF_MRI_FORMAT VER 4', 31)
  type = 'ctf_mri4';
  manufacturer = 'CTF';
  content = 'MRI';
elseif filetype_check_extension(filename, '.hdm')
  type = 'ctf_hdm';
  manufacturer = 'CTF';
  content = 'volume conduction model';
elseif filetype_check_extension(filename, '.hc')
  type = 'ctf_hc';
  manufacturer = 'CTF';
  content = 'headcoil locations';
elseif filetype_check_extension(filename, '.shape')
  type = 'ctf_shape';
  manufacturer = 'CTF';
  content = 'headshape points';
elseif filetype_check_extension(filename, '.shape_info')
  type = 'ctf_shapeinfo';
  manufacturer = 'CTF';
  content = 'headshape information';
elseif filetype_check_extension(filename, '.wts')
  type = 'ctf_wts';
  manufacturer = 'CTF';
  content = 'SAM coefficients, i.e. spatial filter weights';
elseif filetype_check_extension(filename, '.svl')
  type = 'ctf_svl';
  manufacturer = 'CTF';
  content = 'SAM (pseudo-)statistic volumes';
  
  % known Micromed file types
elseif filetype_check_extension(filename, '.trc') && filetype_check_header(filename, '* MICROMED')
  type = 'micromed_trc';
  manufacturer = 'Micromed';
  content = 'Electrophysiological data';
  
  % known BabySQUID file types, these should go before Neuromag
elseif filetype_check_extension(filename, '.fif') && exist(fullfile(p, [f '.eve']), 'file')
  type = 'babysquid_fif';
  manufacturer = 'Tristan Technologies';
  content = 'MEG data';
elseif filetype_check_extension(filename, '.eve') && exist(fullfile(p, [f '.fif']), 'file')
  type = 'babysquid_eve';
  manufacturer = 'Tristan Technologies';
  content = 'MEG data';
  
  % known Neuromag file types
elseif filetype_check_extension(filename, '.fif')
  type = 'neuromag_fif';
  manufacturer = 'Neuromag';
  content = 'MEG header and data';
elseif filetype_check_extension(filename, '.bdip')
  type = 'neuromag_bdip';
  manufacturer = 'Neuromag';
  content = 'dipole model';
  
  % known Yokogawa file types
elseif filetype_check_extension(filename, '.ave') || filetype_check_extension(filename, '.sqd')
  type = 'yokogawa_ave';
  manufacturer = 'Yokogawa';
  content = 'averaged MEG data';
elseif filetype_check_extension(filename, '.con')
  type = 'yokogawa_con';
  manufacturer = 'Yokogawa';
  content = 'continuous MEG data';
elseif filetype_check_extension(filename, '.raw') && filetype_check_header(filename, char([0 0 0 0])) % FIXME, this detection should possibly be improved
  type = 'yokogawa_raw';
  manufacturer = 'Yokogawa';
  content = 'evoked/trialbased MEG data';
elseif filetype_check_extension(filename, '.mrk') && filetype_check_header(filename,  char([0 0 0 0])) % FIXME, this detection should possibly be improved
  type = 'yokogawa_mrk';
  manufacturer = 'Yokogawa';
  content = 'headcoil locations';
elseif filetype_check_extension(filename, '.txt') && numel(strfind(filename,'-coregis')) == 1
  type = 'yokogawa_coregis';
  manufacturer = 'Yokogawa';
  content = 'exported fiducials';
elseif filetype_check_extension(filename, '.txt') && numel(strfind(filename,'-calib')) == 1
  type = 'yokogawa_calib';
  manufacturer = 'Yokogawa';
elseif filetype_check_extension(filename, '.txt') && numel(strfind(filename,'-channel')) == 1
  type = 'yokogawa_channel';
  manufacturer = 'Yokogawa';
elseif filetype_check_extension(filename, '.txt') && numel(strfind(filename,'-property')) == 1
  type = 'yokogawa_property';
  manufacturer = 'Yokogawa';
elseif filetype_check_extension(filename, '.txt') && numel(strfind(filename,'-TextData')) == 1
  type = 'yokogawa_textdata';
  manufacturer = 'Yokogawa';
elseif filetype_check_extension(filename, '.txt') && numel(strfind(filename,'-FLL')) == 1
  type = 'yokogawa_fll';
  manufacturer = 'Yokogawa';
elseif filetype_check_extension(filename, '.hsp')
  type = 'yokogawa_hsp';
  manufacturer = 'Yokogawa';
  
  % Neurosim files; this has to go before the 4D detection
elseif ~isdir(filename) && (strcmp(f,'spikes') || filetype_check_header(filename,'#  Spike information'))
  type = 'neurosim_spikes';
  manufacturer = 'Jan van der Eerden (DCCN)';
  content = 'simulated spikes';
elseif ~isdir(filename) && (strcmp(f,'evolution') || filetype_check_header(filename,'#  Voltages'))
  type = 'neurosim_evolution';
  manufacturer = 'Jan van der Eerden (DCCN)';
  content = 'simulated membrane voltages and currents';
elseif ~isdir(filename) && (strcmp(f,'signals') || filetype_check_header(filename,'#  Internal',2))
  type = 'neurosim_signals';
  manufacturer = 'Jan van der Eerden (DCCN)';
  content = 'simulated network signals';
elseif isdir(filename) && exist(fullfile(filename, 'signals'), 'file') && exist(fullfile(filename, 'spikes'), 'file')
  type = 'neurosim_ds';
  manufacturer = 'Jan van der Eerden (DCCN)';
  content = 'simulated spikes and continuous signals';
  
  % known 4D/BTI file types
elseif filetype_check_extension(filename, '.pdf') && filetype_check_header(filename, 'E|lk') % I am not sure whether this header always applies
  type = '4d_pdf';
  manufacturer = '4D/BTI';
  content = 'raw MEG data (processed data file)';
elseif exist([filename '.m4d'], 'file') && exist([filename '.xyz'], 'file') % these two ascii header files accompany the raw data
  type = '4d_pdf';
  manufacturer = '4D/BTI';
  content = 'raw MEG data (processed data file)';
elseif filetype_check_extension(filename, '.m4d') && exist([filename(1:(end-3)) 'xyz'], 'file') % these come in pairs
  type = '4d_m4d';
  manufacturer = '4D/BTI';
  content = 'MEG header information';
elseif filetype_check_extension(filename, '.xyz') && exist([filename(1:(end-3)) 'm4d'], 'file') % these come in pairs
  type = '4d_xyz';
  manufacturer = '4D/BTI';
  content = 'MEG sensor positions';
elseif isequal(f, 'hs_file') % the filename is "hs_file"
  type = '4d_hs';
  manufacturer = '4D/BTI';
  content = 'head shape';
elseif length(filename)>=4 && ~isempty(strfind(filename,',rf'))
  type = '4d';
  manufacturer = '4D/BTi';
  content = '';
elseif filetype_check_extension(filename, '.el.ascii') && filetype_check_ascii(filename, 20) % assume that there are at least 20 bytes in the file, the example one has 4277 bytes
  type = '4d_el_ascii';
  manufacturer = '4D/BTi';
  content = 'electrode positions';
elseif length(f)<=4 && filetype_check_dir(p, 'config')%&& ~isempty(p) && exist(fullfile(p,'config'), 'file') %&& exist(fullfile(p,'hs_file'), 'file')
  % this could be a 4D file with non-standard/processed name
  % it will be detected as a 4D file when there is a config file in the
  % same directory as the specified file
  type = '4d';
  manufacturer = '4D/BTi';
  content = '';
  
  % known EEProbe file types
elseif filetype_check_extension(filename, '.cnt') && filetype_check_header(filename, 'RIFF')
  type = 'eep_cnt';
  manufacturer = 'EEProbe';
  content = 'EEG';
elseif filetype_check_extension(filename, '.avr') && filetype_check_header(filename, char([38 0 16 0]))
  type = 'eep_avr';
  manufacturer = 'EEProbe';
  content = 'ERP';
elseif filetype_check_extension(filename, '.trg')
  type = 'eep_trg';
  manufacturer = 'EEProbe';
  content = 'trigger information';
elseif filetype_check_extension(filename, '.rej')
  type = 'eep_rej';
  manufacturer = 'EEProbe';
  content = 'rejection marks';
  
  % the yokogawa_mri has to be checked prior to asa_mri, because this one is more strict
elseif filetype_check_extension(filename, '.mri') && filetype_check_header(filename, char(0)) % FIXME, this detection should possibly be improved
  type = 'yokogawa_mri';
  manufacturer = 'Yokogawa';
  content = 'anatomical MRI';
  
  % known ASA file types
elseif filetype_check_extension(filename, '.elc')
  type = 'asa_elc';
  manufacturer = 'ASA';
  content = 'electrode positions';
elseif filetype_check_extension(filename, '.vol')
  type = 'asa_vol';
  manufacturer = 'ASA';
  content = 'volume conduction model';
elseif filetype_check_extension(filename, '.bnd')
  type = 'asa_bnd';
  manufacturer = 'ASA';
  content = 'boundary element model details';
elseif filetype_check_extension(filename, '.msm')
  type = 'asa_msm';
  manufacturer = 'ASA';
  content = 'ERP';
elseif filetype_check_extension(filename, '.msr')
  type = 'asa_msr';
  manufacturer = 'ASA';
  content = 'ERP';
elseif filetype_check_extension(filename, '.dip')
  % FIXME, can also be CTF dipole file
  type = 'asa_dip';
  manufacturer = 'ASA';
elseif filetype_check_extension(filename, '.mri')
  % FIXME, can also be CTF mri file
  type = 'asa_mri';
  manufacturer = 'ASA';
  content = 'MRI image header';
elseif filetype_check_extension(filename, '.iso')
  type = 'asa_iso';
  manufacturer = 'ASA';
  content = 'MRI image data';
  
  % known BCI2000 file types
elseif filetype_check_extension(filename, '.dat') && (filetype_check_header(filename, 'BCI2000') || filetype_check_header(filename, 'HeaderLen='))
  type = 'bci2000_dat';
  manufacturer = 'BCI2000';
  content = 'continuous EEG';
  
  % known Neuroscan file types
elseif filetype_check_extension(filename, '.avg') && filetype_check_header(filename, 'Version 3.0')
  type = 'ns_avg';
  manufacturer = 'Neuroscan';
  content = 'averaged EEG';
elseif filetype_check_extension(filename, '.cnt') && filetype_check_header(filename, 'Version 3.0')
  type = 'ns_cnt';
  manufacturer = 'Neuroscan';
  content = 'continuous EEG';
elseif filetype_check_extension(filename, '.eeg') && filetype_check_header(filename, 'Version 3.0')
  type = 'ns_eeg';
  manufacturer = 'Neuroscan';
  content = 'epoched EEG';
  
elseif filetype_check_extension(filename, '.eeg') && filetype_check_header(filename, 'V3.0')
  type = 'neuroprax_eeg';
  manufacturer = 'eldith GmbH';
  content = 'continuous EEG';
elseif filetype_check_extension(filename, '.ee_')
  type = 'neuroprax_mrk';
  manufacturer = 'eldith GmbH';
  content = 'EEG markers';
  
  % known Analyze & SPM file types
elseif filetype_check_extension(filename, '.hdr')
  type = 'analyze_hdr';
  manufacturer = 'Mayo Analyze';
  content = 'PET/MRI image header';
elseif filetype_check_extension(filename, '.img')
  type = 'analyze_img';
  manufacturer = 'Mayo Analyze';
  content = 'PET/MRI image data';
elseif filetype_check_extension(filename, '.mnc')
  type = 'minc';
  content = 'MRI image data';
elseif filetype_check_extension(filename, '.nii')
  type = 'nifti';
  content = 'MRI image data';
  
  % known FSL file types
elseif filetype_check_extension(filename, '.nii.gz')
  type = 'nifti_fsl';
  content = 'MRI image data';
  
  % known LORETA file types
elseif filetype_check_extension(filename, '.lorb')
  type = 'loreta_lorb';
  manufacturer = 'old LORETA';
  content = 'source reconstruction';
elseif filetype_check_extension(filename, '.slor')
  type = 'loreta_slor';
  manufacturer = 'sLORETA';
  content = 'source reconstruction';
  
  % known AFNI file types
elseif filetype_check_extension(filename, '.brik') || filetype_check_extension(filename, '.BRIK')
  type = 'afni_brik';
  content = 'MRI image data';
elseif filetype_check_extension(filename, '.head') || filetype_check_extension(filename, '.HEAD')
  type = 'afni_head';
  content = 'MRI header data';
  
  % known BrainVison file types
elseif filetype_check_extension(filename, '.vhdr')
  type = 'brainvision_vhdr';
  manufacturer = 'BrainProducts';
  content = 'EEG header';
elseif filetype_check_extension(filename, '.vmrk')
  type = 'brainvision_vmrk';
  manufacturer = 'BrainProducts';
  content = 'EEG markers';
elseif filetype_check_extension(filename, '.vabs')
  type = 'brainvision_vabs';
  manufacturer = 'BrainProducts';
  content = 'Brain Vison Analyzer macro';
elseif filetype_check_extension(filename, '.eeg') && exist(fullfile(p, [f '.vhdr']), 'file')
  type = 'brainvision_eeg';
  manufacturer = 'BrainProducts';
  content = 'continuous EEG data';
elseif filetype_check_extension(filename, '.seg')
  type = 'brainvision_seg';
  manufacturer = 'BrainProducts';
  content = 'segmented EEG data';
elseif filetype_check_extension(filename, '.dat') && exist(fullfile(p, [f '.vhdr']), 'file') &&...
    ~filetype_check_header(filename, 'HeaderLen=') && ~filetype_check_header(filename, 'BESA_SA_IMAGE') &&...
    ~(exist(fullfile(p, [f '.gen']), 'file') || exist(fullfile(p, [f '.generic']), 'file'))
  % WARNING this is a very general name, it could be exported BrainVision
  % data but also a BESA beamformer source reconstruction or BCI2000
  type = 'brainvision_dat';
  manufacturer = 'BrainProducts';
  content = 'exported EEG data';
elseif filetype_check_extension(filename, '.marker')
  type = 'brainvision_marker';
  manufacturer = 'BrainProducts';
  content = 'rejection markers';
  
  % known Polhemus file types
elseif filetype_check_extension(filename, '.pos')
  type = 'polhemus_pos';
  manufacturer = 'BrainProducts/CTF/Polhemus?'; % actually I don't know whose software it is
  content = 'electrode positions';
  
  % known Neuralynx file types
elseif filetype_check_extension(filename, '.nev') || filetype_check_extension(filename, '.Nev')
  type = 'neuralynx_nev';
  manufacturer = 'Neuralynx';
  content = 'event information';
elseif filetype_check_extension(filename, '.ncs') && filetype_check_header(filename, '####')
  type = 'neuralynx_ncs';
  manufacturer = 'Neuralynx';
  content = 'continuous single channel recordings';
elseif filetype_check_extension(filename, '.nse') && filetype_check_header(filename, '####')
  type = 'neuralynx_nse';
  manufacturer = 'Neuralynx';
  content = 'spike waveforms';
elseif filetype_check_extension(filename, '.nts')  && filetype_check_header(filename, '####')
  type = 'neuralynx_nts';
  manufacturer = 'Neuralynx';
  content = 'timestamps only';
elseif filetype_check_extension(filename, '.nvt')
  type = 'neuralynx_nvt';
  manufacturer = 'Neuralynx';
  content = 'video tracker';
elseif filetype_check_extension(filename, '.nst')
  type = 'neuralynx_nst';
  manufacturer = 'Neuralynx';
  content = 'continuous stereotrode recordings';
elseif filetype_check_extension(filename, '.ntt')
  type = 'neuralynx_ntt';
  manufacturer = 'Neuralynx';
  content = 'continuous tetrode recordings';
elseif strcmpi(f, 'logfile') && strcmpi(x, '.txt')  % case insensitive
  type = 'neuralynx_log';
  manufacturer = 'Neuralynx';
  content = 'log information in ASCII format';
elseif ~isempty(strfind(lower(f), 'dma')) && strcmpi(x, '.log')  % this is not a very strong detection
  type = 'neuralynx_dma';
  manufacturer = 'Neuralynx';
  content = 'raw aplifier data directly from DMA';
elseif filetype_check_extension(filename, '.nrd') % see also above, since Cheetah 5.x the file extension has changed
  type = 'neuralynx_dma';
  manufacturer = 'Neuralynx';
  content = 'raw aplifier data directly from DMA';
elseif isdir(filename) && (any(filetype_check_extension({ls.name}, '.nev')) || any(filetype_check_extension({ls.name}, '.Nev')))
  % a regular Neuralynx dataset directory that contains an event file
  type = 'neuralynx_ds';
  manufacturer = 'Neuralynx';
  content = 'dataset';
elseif isdir(filename) && most(filetype_check_extension({ls.name}, '.ncs'))
  % a directory containing continuously sampled channels in Neuralynx format
  type = 'neuralynx_ds';
  manufacturer = 'Neuralynx';
  content = 'continuously sampled channels';
elseif isdir(filename) && most(filetype_check_extension({ls.name}, '.nse'))
  % a directory containing spike waveforms in Neuralynx format
  type = 'neuralynx_ds';
  manufacturer = 'Neuralynx';
  content = 'spike waveforms';
elseif isdir(filename) && most(filetype_check_extension({ls.name}, '.nte'))
  % a directory containing spike timestamps in Neuralynx format
  type = 'neuralynx_ds';
  manufacturer = 'Neuralynx';
  content = 'spike timestamps';
elseif isdir(filename) && most(filetype_check_extension({ls.name}, '.ntt'))
  % a directory containing tetrode recordings in Neuralynx format
  type = 'neuralynx_ds';
  manufacturer = 'Neuralynx';
  content = 'tetrode recordings ';
  
elseif isdir(p) && exist(fullfile(p, 'header'), 'file') && exist(fullfile(p, 'events'), 'file')
  type = 'fcdc_buffer_offline';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'FieldTrip buffer offline dataset';
  
elseif isdir(filename) && exist(fullfile(filename, 'info.xml'), 'file') && exist(fullfile(filename, 'signal1.bin'), 'file')
  % this is an OS X package directory representing a complete EEG dataset
  % it contains a Content file, multiple xml files and one or more signalN.bin files
  type = 'egi_mff';
  manufacturer = 'Electrical Geodesics Incorporated';
  content = 'raw EEG data';
elseif ~isdir(filename) && isdir(p) && exist(fullfile(p, 'info.xml'), 'file') && exist(fullfile(p, 'signal1.bin'), 'file')
  % the file that the user specified is one of the files in an mff package directory
  type = 'egi_mff';
  manufacturer = 'Electrical Geodesics Incorporated';
  content = 'raw EEG data';
  
  % these are formally not Neuralynx file formats, but at the FCDC we use them together with Neuralynx
elseif isdir(filename) && filetype_check_neuralynx_cds(filename)
  % a downsampled Neuralynx DMA file can be split into three seperate lfp/mua/spike directories
  % treat them as one combined dataset
  type = 'neuralynx_cds';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'dataset containing seperate lfp/mua/spike directories';
elseif filetype_check_extension(filename, '.tsl') && filetype_check_header(filename, 'tsl')
  type = 'neuralynx_tsl';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'timestamps from DMA log file';
elseif filetype_check_extension(filename, '.tsh') && filetype_check_header(filename, 'tsh')
  type = 'neuralynx_tsh';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'timestamps from DMA log file';
elseif filetype_check_extension(filename, '.ttl') && filetype_check_header(filename, 'ttl')
  type = 'neuralynx_ttl';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'Parallel_in from DMA log file';
elseif filetype_check_extension(filename, '.bin') && filetype_check_header(filename, {'uint8', 'uint16', 'uint32', 'int8', 'int16', 'int32', 'int64', 'float32', 'float64'})
  type = 'neuralynx_bin';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'single channel continuous data';
elseif isdir(filename) && any(filetype_check_extension({ls.name}, '.ttl')) && any(filetype_check_extension({ls.name}, '.tsl')) && any(filetype_check_extension({ls.name}, '.tsh'))
  % a directory containing the split channels from a DMA logfile
  type = 'neuralynx_sdma';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'split DMA log file';
elseif isdir(filename) && filetype_check_extension(filename, '.sdma')
  % a directory containing the split channels from a DMA logfile
  type = 'neuralynx_sdma';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'split DMA log file';
  
  % known Plexon file types
elseif filetype_check_extension(filename, '.nex')  && filetype_check_header(filename, 'NEX1')
  type = 'plexon_nex';
  manufacturer = 'Plexon';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.plx')  && filetype_check_header(filename, 'PLEX')
  type = 'plexon_plx';
  manufacturer = 'Plexon';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.ddt')
  type = 'plexon_ddt';
  manufacturer = 'Plexon';
elseif isdir(filename) && most(filetype_check_extension({ls.name}, '.nex')) && most(filetype_check_header({ls.name}, 'NEX1'))
  % a directory containing multiple plexon NEX files
  type = 'plexon_ds';
  manufacturer = 'Plexon';
  content = 'electrophysiological data';
  
  % known Cambridge Electronic Design file types
elseif filetype_check_extension(filename, '.smr')
  type = 'ced_son';
  manufacturer = 'Cambridge Electronic Design';
  content = 'Spike2 SON filing system';
  
  % known BESA file types
elseif filetype_check_extension(filename, '.avr') && strcmp(type, 'unknown')
  type = 'besa_avr';  % FIXME, can also be EEProbe average EEG
  manufacturer = 'BESA';
  content = 'average EEG';
elseif filetype_check_extension(filename, '.elp')
  type = 'besa_elp';
  manufacturer = 'BESA';
  content = 'electrode positions';
elseif filetype_check_extension(filename, '.eps')
  type = 'besa_eps';
  manufacturer = 'BESA';
  content = 'digitizer information';
elseif filetype_check_extension(filename, '.sfp')
  type = 'besa_sfp';
  manufacturer = 'BESA';
  content = 'sensor positions';
elseif filetype_check_extension(filename, '.ela')
  type = 'besa_ela';
  manufacturer = 'BESA';
  content = 'sensor information';
elseif filetype_check_extension(filename, '.pdg')
  type = 'besa_pdg';
  manufacturer = 'BESA';
  content = 'paradigm file';
elseif filetype_check_extension(filename, '.tfc')
  type = 'besa_tfc';
  manufacturer = 'BESA';
  content = 'time frequency coherence';
elseif filetype_check_extension(filename, '.mul')
  type = 'besa_mul';
  manufacturer = 'BESA';
  content = 'multiplexed ascii format';
elseif filetype_check_extension(filename, '.dat') && filetype_check_header(filename, 'BESA_SA')  % header can start with BESA_SA_IMAGE or BESA_SA_MN_IMAGE
  type = 'besa_src';
  manufacturer = 'BESA';
  content = 'beamformer source reconstruction';
elseif filetype_check_extension(filename, '.swf') && filetype_check_header(filename, 'Npts=')
  type = 'besa_swf';
  manufacturer = 'BESA';
  content = 'beamformer source waveform';
elseif filetype_check_extension(filename, '.bsa')
  type = 'besa_bsa';
  manufacturer = 'BESA';
  content = 'beamformer source locations and orientations';
elseif exist(fullfile(p, [f '.dat']), 'file') && (exist(fullfile(p, [f '.gen']), 'file') || exist(fullfile(p, [f '.generic']), 'file'))
  type = 'besa_sb';
  manufacturer = 'BESA';
  content = 'simple binary channel data with a seperate generic ascii header';
  
  % known Dataq file formats
elseif filetype_check_extension(upper(filename), '.WDQ')
  type         = 'dataq_wdq';
  manufacturer = 'dataq instruments';
  content      = 'electrophysiological data';
  
  % old files from Pascal Fries' PhD research at the MPI
elseif filetype_check_extension(filename, '.dap') && filetype_check_header(filename, char(1))
  type = 'mpi_dap';
  manufacturer = 'MPI Frankfurt';
  content = 'electrophysiological data';
elseif isdir(filename) && ~isempty(cell2mat(regexp({ls.name}, '.dap$')))
  type = 'mpi_ds';
  manufacturer = 'MPI Frankfurt';
  content = 'electrophysiological data';
  
  % Frankfurt SPASS format, which uses the Labview Datalog (DTLG) format
elseif  filetype_check_extension(filename, '.ana') && filetype_check_header(filename, 'DTLG')
  type = 'spass_ana';
  manufacturer = 'MPI Frankfurt';
  content = 'electrophysiological data';
elseif  filetype_check_extension(filename, '.swa') && filetype_check_header(filename, 'DTLG')
  type = 'spass_swa';
  manufacturer = 'MPI Frankfurt';
  content = 'electrophysiological data';
elseif  filetype_check_extension(filename, '.spi') && filetype_check_header(filename, 'DTLG')
  type = 'spass_spi';
  manufacturer = 'MPI Frankfurt';
  content = 'electrophysiological data';
elseif  filetype_check_extension(filename, '.stm') && filetype_check_header(filename, 'DTLG')
  type = 'spass_stm';
  manufacturer = 'MPI Frankfurt';
  content = 'electrophysiological data';
elseif  filetype_check_extension(filename, '.bhv') && filetype_check_header(filename, 'DTLG')
  type = 'spass_bhv';
  manufacturer = 'MPI Frankfurt';
  content = 'electrophysiological data';
  
  % known Chieti ITAB file types
elseif filetype_check_extension(filename, '.raw') && (filetype_check_header(filename, 'FORMAT: ATB-BIOMAGDATA') || filetype_check_header(filename, '[HeaderType]'))
  type = 'itab_raw';
  manufacturer = 'Chieti ITAB';
  content = 'MEG data, including sensor positions';
elseif filetype_check_extension(filename, '.raw.mhd')
  type = 'itab_mhd';
  manufacturer = 'Chieti ITAB';
  content = 'MEG header data, including sensor positions';
elseif filetype_check_extension(filename, '.asc') && ~filetype_check_header(filename, '**')
  type = 'itab_asc';
  manufacturer = 'Chieti ITAB';
  content = 'headshape digitization file';
  
  % known Nexstim file types
elseif filetype_check_extension(filename, '.nxe')
  type = 'nexstim_nxe';
  manufacturer = 'Nexstim';
  content = 'electrophysiological data';
  
  % known Tucker-Davis-Technology file types
elseif filetype_check_extension(filename, '.tbk')
  type = 'tdt_tbk';
  manufacturer = 'Tucker-Davis-Technology';
  content = 'database/tank meta-information';
elseif filetype_check_extension(filename, '.tdx')
  type = 'tdt_tdx';
  manufacturer = 'Tucker-Davis-Technology';
  content = 'database/tank meta-information';
elseif filetype_check_extension(filename, '.tsq')
  type = 'tdt_tsq';
  manufacturer = 'Tucker-Davis-Technology';
  content = 'block header information';
elseif filetype_check_extension(filename, '.tev')
  type = 'tdt_tev';
  manufacturer = 'Tucker-Davis-Technology';
  content = 'electrophysiological data';
  
elseif (filetype_check_extension(filename, '.dat') ||  filetype_check_extension(filename, '.Dat')) && (exist(fullfile(p, [f '.ini']), 'file') || exist(fullfile(p, [f '.Ini']), 'file'))
  % this should go before curry_dat
  type = 'deymed_dat';
  manufacturer = 'Deymed';
  content = 'raw eeg data';
elseif (filetype_check_extension(filename, '.ini') ||  filetype_check_extension(filename, '.Ini')) && (exist(fullfile(p, [f '.dat']), 'file') || exist(fullfile(p, [f '.Dat']), 'file'))
  type = 'deymed_ini';
  manufacturer = 'Deymed';
  content = 'eeg header information';
  
  % known Curry V4 file types
elseif filetype_check_extension(filename, '.dap')
  type = 'curry_dap';   % FIXME, can also be MPI Frankfurt electrophysiological data
  manufacturer = 'Curry';
  content = 'data parameter file';
elseif filetype_check_extension(filename, '.dat')
  type = 'curry_dat';
  manufacturer = 'Curry';
  content = 'raw data file';
elseif filetype_check_extension(filename, '.rs4')
  type = 'curry_rs4';
  manufacturer = 'Curry';
  content = 'sensor geometry file';
elseif filetype_check_extension(filename, '.par')
  type = 'curry_par';
  manufacturer = 'Curry';
  content = 'data or image parameter file';
elseif filetype_check_extension(filename, '.bd0') || filetype_check_extension(filename, '.bd1') || filetype_check_extension(filename, '.bd2') || filetype_check_extension(filename, '.bd3') || filetype_check_extension(filename, '.bd4') || filetype_check_extension(filename, '.bd5') || filetype_check_extension(filename, '.bd6') || filetype_check_extension(filename, '.bd7') || filetype_check_extension(filename, '.bd8') || filetype_check_extension(filename, '.bd9')
  type = 'curry_bd';
  manufacturer = 'Curry';
  content = 'BEM description file';
elseif filetype_check_extension(filename, '.bt0') || filetype_check_extension(filename, '.bt1') || filetype_check_extension(filename, '.bt2') || filetype_check_extension(filename, '.bt3') || filetype_check_extension(filename, '.bt4') || filetype_check_extension(filename, '.bt5') || filetype_check_extension(filename, '.bt6') || filetype_check_extension(filename, '.bt7') || filetype_check_extension(filename, '.bt8') || filetype_check_extension(filename, '.bt9')
  type = 'curry_bt';
  manufacturer = 'Curry';
  content = 'BEM transfer matrix file';
elseif filetype_check_extension(filename, '.bm0') || filetype_check_extension(filename, '.bm1') || filetype_check_extension(filename, '.bm2') || filetype_check_extension(filename, '.bm3') || filetype_check_extension(filename, '.bm4') || filetype_check_extension(filename, '.bm5') || filetype_check_extension(filename, '.bm6') || filetype_check_extension(filename, '.bm7') || filetype_check_extension(filename, '.bm8') || filetype_check_extension(filename, '.bm9')
  type = 'curry_bm';
  manufacturer = 'Curry';
  content = 'BEM full matrix file';
elseif filetype_check_extension(filename, '.dig')
  type = 'curry_dig';
  manufacturer = 'Curry';
  content = 'digitizer file';
  
  % known SR Research eyelink file formats
elseif filetype_check_extension(filename, '.asc') && filetype_check_header(filename, '**')
  type = 'eyelink_asc';
  manufacturer = 'SR Research (ascii)';
  content = 'eyetracker data';
elseif filetype_check_extension(filename, '.edf') && filetype_check_header(filename, 'SR_RESEARCH')
  type = 'eyelink_edf';
  manufacturer = 'SR Research';
  content = 'eyetracker data (binary)';
  
  % known Curry V2 file types
elseif filetype_check_extension(filename, '.sp0') || filetype_check_extension(filename, '.sp1') || filetype_check_extension(filename, '.sp2') || filetype_check_extension(filename, '.sp3') || filetype_check_extension(filename, '.sp4') || filetype_check_extension(filename, '.sp5') || filetype_check_extension(filename, '.sp6') || filetype_check_extension(filename, '.sp7') || filetype_check_extension(filename, '.sp8') || filetype_check_extension(filename, '.sp9')
  type = 'curry_sp';
  manufacturer = 'Curry';
  content = 'point list';
elseif filetype_check_extension(filename, '.s10') || filetype_check_extension(filename, '.s11') || filetype_check_extension(filename, '.s12') || filetype_check_extension(filename, '.s13') || filetype_check_extension(filename, '.s14') || filetype_check_extension(filename, '.s15') || filetype_check_extension(filename, '.s16') || filetype_check_extension(filename, '.s17') || filetype_check_extension(filename, '.s18') || filetype_check_extension(filename, '.s19') || filetype_check_extension(filename, '.s20') || filetype_check_extension(filename, '.s21') || filetype_check_extension(filename, '.s22') || filetype_check_extension(filename, '.s23') || filetype_check_extension(filename, '.s24') || filetype_check_extension(filename, '.s25') || filetype_check_extension(filename, '.s26') || filetype_check_extension(filename, '.s27') || filetype_check_extension(filename, '.s28') || filetype_check_extension(filename, '.s29') || filetype_check_extension(filename, '.s30') || filetype_check_extension(filename, '.s31') || filetype_check_extension(filename, '.s32') || filetype_check_extension(filename, '.s33') || filetype_check_extension(filename, '.s34') || filetype_check_extension(filename, '.s35') || filetype_check_extension(filename, '.s36') || filetype_check_extension(filename, '.s37') || filetype_check_extension(filename, '.s38') || filetype_check_extension(filename, '.s39')
  type = 'curry_s';
  manufacturer = 'Curry';
  content = 'triangle or tetraedra list';
elseif filetype_check_extension(filename, '.pom')
  type = 'curry_pom';
  manufacturer = 'Curry';
  content = 'anatomical localization file';
elseif filetype_check_extension(filename, '.res')
  type = 'curry_res';
  manufacturer = 'Curry';
  content = 'functional localization file';
  
  % known MBFYS file types
elseif filetype_check_extension(filename, '.tri')
  type = 'mbfys_tri';
  manufacturer = 'MBFYS';
  content = 'triangulated surface';
elseif filetype_check_extension(filename, '.ama') && filetype_check_header(filename, [10 0 0 0])
  type = 'mbfys_ama';
  manufacturer = 'MBFYS';
  content = 'BEM volume conduction model';
  
  % Electrical Geodesics Incorporated formats
  % the egi_mff format is checked earlier
elseif (filetype_check_extension(filename, '.egis') || filetype_check_extension(filename, '.ave') || filetype_check_extension(filename, '.gave') || filetype_check_extension(filename, '.raw')) && (filetype_check_header(filename, [char(1) char(2) char(3) char(4) char(255) char(255)]) || filetype_check_header(filename, [char(3) char(4) char(1) char(2) char(255) char(255)]))
  type = 'egi_egia';
  manufacturer = 'Electrical Geodesics Incorporated';
  content = 'averaged EEG data';
elseif (filetype_check_extension(filename, '.egis') || filetype_check_extension(filename, '.ses') || filetype_check_extension(filename, '.raw')) && (filetype_check_header(filename, [char(1) char(2) char(3) char(4) char(0) char(3)]) || filetype_check_header(filename, [char(3) char(4) char(1) char(2) char(0) char(3)]))
  type = 'egi_egis';
  manufacturer = 'Electrical Geodesics Incorporated';
  content = 'raw EEG data';
elseif (filetype_check_extension(filename, '.sbin') || filetype_check_extension(filename, '.raw'))
  % note that the Chieti MEG data format also has the extension *.raw
  % but that can be detected by looking at the file header
  type = 'egi_sbin';
  manufacturer = 'Electrical Geodesics Incorporated';
  content = 'averaged EEG data';
  
  % FreeSurfer file formats, see also http://www.grahamwideman.com/gw/brain/fs/surfacefileformats.htm
elseif filetype_check_extension(filename, '.mgz')
  type = 'freesurfer_mgz';
  manufacturer = 'FreeSurfer';
  content = 'anatomical MRI';
elseif filetype_check_extension(filename, '.mgh')
  type = 'freesurfer_mgh';
  manufacturer = 'FreeSurfer';
  content = 'anatomical MRI';
elseif filetype_check_header(filename, [255 255 254])
  % FreeSurfer Triangle Surface Binary Format
  type = 'freesurfer_triangle_binary';	% there is also an ascii triangle format
  manufacturer = 'FreeSurfer';
  content = 'surface description';
elseif filetype_check_header(filename, [255 255 255])
  % Quadrangle File
  type = 'freesurfer_quadrangle'; % there is no ascii quadrangle format
  manufacturer = 'FreeSurfer';
  content = 'surface description';
elseif filetype_check_header(filename, [255 255 253]) && ~exist([filename(1:(end-4)) '.mat'], 'file')
  % "New" Quadrangle File
  type = 'freesurfer_quadrangle_new';
  manufacturer = 'FreeSurfer';
  content = 'surface description';
elseif filetype_check_extension(filename, '.curv') && filetype_check_header(filename, [255 255 255])
  % "New" Curv File
  type = 'freesurfer_curv_new';
  manufacturer = 'FreeSurfer';
  content = 'surface description';
elseif filetype_check_extension(filename, '.annot')
  % Freesurfer annotation file
  type = 'freesurfer_annot';
  manufacturer = 'FreeSurfer';
  content = 'parcellation annotation';
elseif filetype_check_extension(filename, '.txt') && numel(strfind(filename,'_nrs_')) == 1
  % This may be improved by looking into the file, rather than assuming the
  % filename has "_nrs_" somewhere. Also, distinction by the different file
  % types could be made
  type = 'bucn_nirs';
  manufacturer = 'BUCN';
  content = 'ascii formatted nirs data';
  
  % known TETGEN file types, see http://tetgen.berlios.de/fformats.html
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.poly']), 'file')
  type = 'tetgen_poly';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with piecewise linear complex';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.smesh']), 'file')
  type = 'tetgensmesh';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with simple piecewise linear complex';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.ele']), 'file')
  type = 'tetgen_ele';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with tetrahedra';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.face']), 'file')
  type = 'tetgen_face';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with triangular faces';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.edge']), 'file')
  type = 'tetgen_edge';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with boundary edges';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.vol']), 'file')
  type = 'tetgen_vol';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with maximum volumes';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.var']), 'file')
  type = 'tetgen_var';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with variant constraints for facets/segments';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100) && exist(fullfile(p, [f '.neigh']), 'file')
  type = 'tetgen_neigh';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with neighbors';
elseif any(filetype_check_extension(filename, {'.node' '.poly' '.smesh' '.ele' '.face' '.edge' '.vol' '.var' '.neigh'})) && exist(fullfile(p, [f '.node']), 'file') && filetype_check_ascii(fullfile(p, [f '.node']), 100)
  type = 'tetgen_node';
  manufacturer = 'TetGen, see http://tetgen.berlios.de';
  content = 'geometrical data desribed with only nodes';
  
  % some other known file types
elseif length(filename)>4 && exist([filename(1:(end-4)) '.mat'], 'file') && exist([filename(1:(end-4)) '.bin'], 'file')
  % this is a self-defined FCDC data format, consisting of two files
  % there is a matlab V6 file with the header and a binary file with the data (multiplexed, ieee-le, double)
  type = 'fcdc_matbin';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'multiplexed electrophysiology data';
elseif filetype_check_extension(filename, '.lay')
  type = 'layout';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'layout of channels for plotting';
elseif filetype_check_extension(filename, '.stl')
  type = 'stl';
  manufacturer = 'various';
  content = 'stereo litography file';
elseif filetype_check_extension(filename, '.dcm') || filetype_check_extension(filename, '.ima') || filetype_check_header(filename, 'DICM', 128)
  type = 'dicom';
  manufacturer = 'Dicom';
  content = 'image data';
elseif filetype_check_extension(filename, '.trl')
  type = 'fcdc_trl';
  manufacturer = 'Donders Centre for Cognitive Neuroimaging';
  content = 'trial definitions';
elseif filetype_check_extension(filename, '.bdf') && filetype_check_header(filename, [255 'BIOSEMI'])
  type = 'biosemi_bdf';
  manufacturer = 'Biosemi Data Format';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.edf')
  type = 'edf';
  manufacturer = 'European Data Format';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.gdf') && filetype_check_header(filename, 'GDF')
  type = 'gdf';
  manufacturer = 'BIOSIG - Alois Schloegl';
  content = 'biosignals';
elseif filetype_check_extension(filename, '.mat') && filetype_check_header(filename, 'MATLAB') && filetype_check_spmeeg_mat(filename)
  type = 'spmeeg_mat';
  manufacturer = 'Wellcome Trust Centre for Neuroimaging, UCL, UK';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.mat') && filetype_check_header(filename, 'MATLAB') && filetype_check_gtec_mat(filename)
  type = 'gtec_mat';
  manufacturer = 'Guger Technologies, http://www.gtec.at';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.mat') && filetype_check_header(filename, 'MATLAB') && filetype_check_ced_spike6mat(filename)
  type = 'ced_spike6mat';
  manufacturer = 'Cambridge Electronic Design Limited';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.mat') && filetype_check_header(filename, 'MATLAB')
  type = 'matlab';
  manufacturer = 'Matlab';
  content = 'Matlab binary data';
elseif filetype_check_header(filename, 'RIFF', 0) && filetype_check_header(filename, 'WAVE', 8)
  type = 'riff_wave';
  manufacturer = 'Microsoft';
  content = 'audio';
elseif filetype_check_extension(filename, '.txt')
  type = 'ascii_txt';
  manufacturer = '';
  content = '';
elseif filetype_check_extension(filename, '.pol')
  type = 'polhemus_fil';
  manufacturer = 'Functional Imaging Lab, London, UK';
  content = 'headshape points';
elseif filetype_check_extension(filename, '.set')
  type = 'eeglab_set';
  manufacturer = 'Swartz Center for Computational Neuroscience, San Diego, USA';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.erp')
  type = 'eeglab_erp';
  manufacturer = 'Swartz Center for Computational Neuroscience, San Diego, USA';
  content = 'electrophysiological data';
elseif filetype_check_extension(filename, '.t') && filetype_check_header(filename, '%%BEGINHEADER')
  type = 'mclust_t';
  manufacturer = 'MClust';
  content = 'sorted spikes';
elseif filetype_check_header(filename, 26)
  type = 'nimh_cortex';
  manufacturer = 'NIMH Laboratory of Neuropsychology, http://www.cortex.salk.edu';
  content = 'events and eye channels';
elseif filetype_check_extension(filename, '.foci') && filetype_check_header(filename, '<?xml')
  type = 'caret_foci';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.border') && filetype_check_header(filename, '<?xml')
  type = 'caret_border';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.spec') && (filetype_check_header(filename, '<?xml') || filetype_check_header(filename, 'BeginHeader'))
  type = 'caret_spec';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.gii') && ~isempty(strfind(filename, '.coord.')) && filetype_check_header(filename, '<?xml')
  type = 'caret_coord';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.gii') && ~isempty(strfind(filename, '.topo.')) && filetype_check_header(filename, '<?xml')
  type = 'caret_topo';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.gii') && ~isempty(strfind(filename, '.surf.')) && filetype_check_header(filename, '<?xml')
  type = 'caret_surf';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.gii') && ~isempty(strfind(filename, '.label.')) && filetype_check_header(filename, '<?xml')
  type = 'caret_label';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.gii') && ~isempty(strfind(filename, '.func.')) && filetype_check_header(filename, '<?xml')
  type = 'caret_func';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.gii') && ~isempty(strfind(filename, '.shape.')) && filetype_check_header(filename, '<?xml')
  type = 'caret_shape';
  manufacturer = 'Caret and ConnectomeWB';
elseif filetype_check_extension(filename, '.gii') && filetype_check_header(filename, '<?xml')
  type = 'gifti';
  manufacturer = 'Neuroimaging Informatics Technology Initiative';
  content = 'tesselated surface description';
elseif filetype_check_extension(filename, '.v')
  type = 'vista';
  manufacturer = 'University of British Columbia, Canada, http://www.cs.ubc.ca/nest/lci/vista/vista.html';
  content = 'A format for computer vision research, contains meshes or volumes';
elseif filetype_check_extension(filename, '.tet')
  type = 'tet';
  manufacturer = 'a.o. INRIA, see http://shapes.aimatshape.net/';
  content = 'tetraedral mesh';
elseif filetype_check_extension(filename, '.nc')
  type = 'netmeg';
  manufacturer = 'Center for Biomedical Research Excellence (COBRE), see http://cobre.mrn.org/megsim/tools/netMEG/netMEG.html';
  content = 'MEG data';
elseif filetype_check_extension(filename, 'trk')
  type = 'trackvis_trk';
  manufacturer = 'Martinos Center for Biomedical Imaging, see http://www.trackvis.org';
  content = 'fiber tracking data from diffusion MR imaging';
elseif filetype_check_extension(filename, '.xml') && filetype_check_header(filename, '<EEGMarkerList', 39)
  type = 'localite_pos';
  manufacturer = 'Localite';
  content = 'EEG electrode positions';
elseif filetype_check_extension(filename, '.mbi')
  type = 'manscan_mbi';
  manufacturer = 'MANSCAN';
  content  = 'EEG header';
elseif filetype_check_extension(filename, '.mb2')
  type = 'manscan_mb2';
  manufacturer = 'MANSCAN';
  content  = 'EEG data';    
elseif filetype_check_header(filename, 'ply')
  type = 'ply';
  manufacturer = 'Stanford Triangle Format';
  content = 'three dimensional data from 3D scanners, see http://en.wikipedia.org/wiki/PLY_(file_format)';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% finished determining the filetype
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(type, 'unknown')
  warning_once(sprintf('could not determine filetype of %s', filename));
end

if ~isempty(desired)
  % return a boolean value instead of a descriptive string
  type = strcmp(type, desired);
end

% remember the current input and output arguments, so that they can be
% reused on a subsequent call in case the same input argument is given
current_argout = {type};
if isempty(previous_argin) && ~strcmp(type, 'unknown')
  previous_argin  = current_argin;
  previous_argout = current_argout;
  previous_pwd    = current_pwd;
elseif  isempty(previous_argin) && (exist(filename,'file') || exist(filename,'dir')) && strcmp(type, 'unknown') % if the type is unknown, but the file or dir exists, save the current output
  previous_argin  = current_argin;
  previous_argout = current_argout;
  previous_pwd    = current_pwd;
else
  % don't remember in case unknown
  previous_argin  = [];
  previous_argout = [];
  previous_pwd    = [];
end

return % filetype main()


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that helps in deciding whether a directory with files should
% be treated as a "dataset". This function returns a logical 1 (TRUE) if more
% than half of the element of a vector are nonzero number or are 1 or TRUE.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = most(x)
x = x(~isnan(x(:)));
y = sum(x==0)<ceil(length(x)/2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that always returns a true value
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = filetype_true(varargin)
y = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that checks for CED spike6 mat file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = filetype_check_ced_spike6mat(filename)
res = 1;
var = whos('-file', filename);

% Check whether all the variables in the file are structs (representing channels)
if ~all(strcmp('struct', unique({var(:).class})) == 1)
  res = 0;
  return;
end

var = load(filename, var(1).name);
var = struct2cell(var);

% Check whether the fields of the first struct have some particular names
fnames = {
  'title'
  'comment'
  'interval'
  'scale'
  'offset'
  'units'
  'start'
  'length'
  'values'
  'times'
  };

res = (numel(intersect(fieldnames(var{1}), fnames)) >= 5);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that checks for a SPM eeg/meg mat file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = filetype_check_spmeeg_mat(filename)
% check for the accompanying *.dat file
res = exist([filename(1:(end-4)) '.dat'], 'file');
if ~res, return; end
% check the content of the *.mat file
var = whos('-file', filename);
res = res && numel(var)==1;
res = res && strcmp('D', getfield(var, {1}, 'name'));
res = res && strcmp('struct', getfield(var, {1}, 'class'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that checks for a GTEC mat file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = filetype_check_gtec_mat(filename)
% check the content of the *.mat file
var = whos('-file', filename);
res = length(intersect({'log', 'names'}, {var.name}))==2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that checks the presence of a specified file in a directory
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = filetype_check_dir(p, filename)
if ~isempty(p)
  d = dir(p);
else
  d = dir;
end
res = any(strcmp(filename,{d.name}));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that checks whether the directory is neuralynx_cds
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = filetype_check_neuralynx_cds(filename)

res=false;
files=dir(filename);
dirlist=files([files.isdir]);

% 1) check for a subdirectory with extension .lfp, .mua or .spike
haslfp   = any(filetype_check_extension({dirlist.name}, 'lfp'));
hasmua   = any(filetype_check_extension({dirlist.name}, 'mua'));
hasspike = any(filetype_check_extension({dirlist.name}, 'spike'));

% 2) check for each of the subdirs being a neuralynx_ds
if haslfp || hasmua || hasspike
  sel=find(filetype_check_extension({dirlist.name}, 'lfp')+...
    filetype_check_extension({dirlist.name}, 'mua')+...
    filetype_check_extension({dirlist.name}, 'spike'));
  
  neuralynxdirs=cell(1,length(sel));
  
  for n=1:length(sel)
    neuralynxdirs{n}=fullfile(filename, dirlist(sel(n)).name);
  end
  
  res=any(ft_filetype(neuralynxdirs, 'neuralynx_ds'));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION that checks whether the file contains only ascii characters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = filetype_check_ascii(filename, len)
% See http://en.wikipedia.org/wiki/ASCII
if exist(filename, 'file')
  fid = fopen(filename, 'rt');
  bin = fread(fid, len, 'uint8=>uint8');
  fclose(fid);
  printable = bin>31 & bin<127;  % the printable characters, represent letters, digits, punctuation marks, and a few miscellaneous symbols
  special   = bin==10 | bin==13 | bin==11; % line feed, form feed, tab
  res = all(printable | special);
else
  % always return true if the file does not (yet) exist, this is important
  % for determining the format to which data should be written
  res = 1;
end
