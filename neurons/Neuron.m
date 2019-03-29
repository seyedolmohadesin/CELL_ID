classdef Neuron < handle
    %NEURON A neuron.
    %
    %   A neuron has a position within an image, color, list of potential
    %   IDs, probabilities associated with these IDs, and methods to draw
    %   it within a GUI.
    
    properties (Access = private)
        brain
    end
    
    properties
        position % neuron pixel position (x,y,z)
        color % neuron color (R,G,B,W,...), W = white channel, values=[0-255]
        baseline % baseline noise values (R,G,B,W,...), values=[-1,1]
        covariance % 3x3 covariance matrix that's fit to the neurong
        deterministic_id  % neuron ID assigned by the deterministic model
        probabilistic_ids % neuron IDs listed by descending probability
        probabilistic_probs % neuron ID probabilities
        annotation = '' % neuron user selected annotation
        annotation_confidence = -1 % user confidence about annotation
        rank % ranks of the neuron based on the confidence assigned by sinkhorn algorithm
        is_selected = false % GUI related parameter specifying if the neuron is selected in the software or not
    end
    
    methods
        function obj = Neuron(superpixel)
            %Neuron Construct an instance of this class.
            %   converts a superpixel to a Neuron instance by reading out
            %   the variables inside superpixels and assigning them to the
            %   properties of the Neuron instance.
            obj.position = superpixel.mean;
            obj.color = superpixel.color;
            obj.baseline = superpixel.baseline;
            obj.covariance = squeeze(superpixel.cov);
            
            if isfield(superpixel, 'deterministic_id')
                obj.deterministic_id = superpixel.deterministic_id{1};
            end
            if isfield(superpixel, 'probabilistic_ids')
                obj.probabilistic_ids = superpixel.probabilistic_ids;
            end
            if isfield(superpixel, 'annotation')
                obj.annotation = superpixel.annotation{1};
            end
            if isfield(superpixel, 'annotation_confidence')
                obj.annotation_confidence = superpixel.annotation_confidence;
            end
            if isfield(superpixel, 'probabilistic_probs')
                obj.probabilistic_probs = superpixel.probabilistic_probs;
            end
            
        end
        
        function rotate(obj, rot, sz, newsz)
            %ROTATE rotates the neuron and translates it according to new
            %image space.
            %   rot: a 4x4 rotation matrix or a 1x3 vector consisting
            %   rotation angles.
            %   sz: size of the image before rotation used to translate
            %   before rotation.
            %   newsz: size of the image after rotation used to translate
            %   after rotation.
            
            if isvector(rot)
                rot_mat = makehgtform('xrotate',rot(1),'yrotate',rot(2),'zrotate',rot(3));
            else
                rot_mat = rot;
            end
            
            obj.position([2,1,3]) = (obj.position([2,1,3])-((sz([2,1,3])+1)/2))*rot_mat(1:3,1:3)+((newsz([2,1,3])+1)/2);
            obj.covariance([2,1,3],[2,1,3]) = rot_mat(1:3,1:3)*obj.covariance([2,1,3],[2,1,3])*rot_mat(1:3,1:3)';
        end
        
        function addToBrain(obj, b)
            %ADDTOBRAIN Add this neuron to a brain image.
            obj.brain = b;
        end

        function remove(obj)
            %REMOVE Remove this neuron.
            if ~isempty(obj.brain)
                obj.brain.remove(obj);
            end
        end
        
        function color = get_marker_color(obj)
            %GET_MARKER_COLORS specifies the marker color of the current
            %neuron according to the annotation confidence.
            if obj.annotation_confidence == 0
                color = [1,0,0]; % user added neuron but no ID yet or user annotated neuron as “?” (red)
            elseif obj.annotation_confidence == 1
                color = [0,1,0]; % user ID’d neuron as 100% correct (green)
            elseif obj.annotation_confidence == 0.5
                color = [1,1,0]; % user ID’d neuron as low probability (yellow)
            elseif obj.annotation_confidence == -1
                color = [1,0.5,0]; % model ID’d neuron (orange)
            end
        end
        
        function size = get_marker_size(obj)
            %GET_MARKER_SIZE specifies the marker size of the current
            %neuron according to whether it is selected in the software or
            %not.
            if ~obj.is_selected
                size = 60;
            else
                size = 180;
            end
        end
        
        function size = get_line_size(obj)
            %GET_MARKER_SIZE specifies the line size of the current
            %neuron according to whether it is selected in the software or
            %not.
            if ~obj.is_selected
                size = 2;
            else
                size = 4;
            end
        end
        
        function recon = get_3d_reconstruction(obj,nsz,trunc)
            %GET_3D_RECONSTRUCTION reconstructs the 3D colored shape of the
            %current neuron according to its properties.
            %   nsz: size of the reconstructed image
            %   trunc: truncation value used for reconstruction.
            %   recon: (X,Y,Z,C) 4D double array.
            recon = simulate_gaussian(2*nsz+1, ... % size
                nsz+1+obj.position-round(obj.position), ... % center
                obj.covariance, ... % cov
                obj.color, ... % colors
                zeros(size(obj.color)), ... % baseline mean
                zeros(size(obj.color)), ... % baseline std
                trunc); % truncation
        end
        
    end
end