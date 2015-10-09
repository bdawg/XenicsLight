%handle_light - trivial derived class that hides most of handle's methods
% licensed under cc-wiki (http://creativecommons.org/licenses/by-sa/3.0/) 
% with attribution required
% (http://blog.stackoverflow.com/2009/06/attribution-required/)
%
% Based on http://stackoverflow.com/a/13050111/527489 by 
% sclarke81 (http://stackoverflow.com/users/1326370/sclarke81)

classdef handleAllHidden < handle
    methods (Hidden)
        %% Following Hidden functions are to hide inherited
        %   addlistener  - Add listener for event.
        %   delete       - Delete a handle object.
        %   eq           - Test handle equality.
        %   findobj      - Find objects with specified property values.
        %   findprop     - Find property of MATLAB handle object.
        %   ge           - Greater than or equal relation.
        %   gt           - Greater than relation.
        %   isvalid      - Test handle validity. [CANNOT HIDE]
        %   le           - Less than or equal relation for handles.
        %   lt           - Less than relation for handles.
        %   ne           - Not equal relation for handles.
        %   notify       - Notify listeners of event.
        function lh = addlistener(varargin)
            lh = addlistener@handle(varargin{:});
        end
        function delete(varargin)
            delete@handle(varargin{:});
        end
        function TF = eq(varargin)
            TF = eq@handle(varargin{:});
        end
        function Hmatch = findobj(varargin)
            Hmatch = findobj@handle(varargin{:});
        end
        function p = findprop(varargin)
            p = findprop@handle(varargin{:});
        end
        function TF = ge(varargin)
            TF = ge@handle(varargin{:});
        end
        function TF = gt(varargin)
            TF = gt@handle(varargin{:});
        end
        function TF = le(varargin)
            TF = le@handle(varargin{:});
        end
        function TF = lt(varargin)
            TF = lt@handle(varargin{:});
        end
        function TF = ne(varargin)
            TF = ne@handle(varargin{:});
        end
        function notify(varargin)
            notify@handle(varargin{:});
        end
    end    
end