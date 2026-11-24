function g = radiator_geometry(geom)
%RADIATOR_GEOMETRY  Areas and passages of the radiator core.
%
%   g = radiator_geometry(p.geom) turns the measured and assumed dimensions in
%   cooling_params into the areas the heat-transfer model needs.
%
%   Everything is worked out first and g is built in one step at the end,
%   because MATLAB cannot compile a struct that gains fields after it has
%   been read (this function also runs inside the Simulink model).

%#codegen

Fp = 25.4e-3/geom.fpi;                     % fin pitch along the tube
Fl = geom.tube_pitch - geom.tube_thick;    % fin height = gap between two tubes
L  = geom.tube_length;
Td = geom.core_depth;
n  = geom.n_tubes;
nr = geom.fin_rows;

% air side
width   = nr*Fl + n*geom.tube_thick;       % width of the finned core
A_front = width*L;                         % frontal area the air passes through
n_fins  = L/Fp;                            % fin plates in one row
A_fin   = nr*n_fins*2*Fl*Td;               % both faces of every fin plate
contact = n_fins*geom.fin_thick*Td;        % fin roots covering one tube face
A_prim  = n*(2*(Td*L - contact) + 2*geom.tube_thick*L);   % exposed tube surface
A_free  = nr*Fl*L*(1 - geom.fin_thick/Fp); % open area between the fins

% coolant side
wi    = Td - 2*geom.wall;                  % inside width of one tube
hi    = geom.tube_thick - 2*geom.wall;     % inside height of one tube
P_wet = 2*(wi + hi);                       % wetted perimeter of one tube

g = struct( ...
    'Fp',      Fp, ...
    'Fl',      Fl, ...
    'Ll',      geom.louver_ratio*Fl, ...   % louver length
    'width',   width, ...
    'A_front', A_front, ...
    'A_fin',   A_fin, ...
    'A_prim',  A_prim, ...
    'A_air',   A_fin + A_prim, ...
    'A_free',  A_free, ...
    'sigma',   A_free/A_front, ...
    'w_in',    wi, ...
    'h_in',    hi, ...
    'A_flow',  n*wi*hi, ...                % flow area of all tubes together
    'P_wet',   P_wet, ...
    'Dh',      4*wi*hi/P_wet, ...          % hydraulic diameter
    'A_cool',  n*P_wet*L, ...              % wetted area of all tubes
    'aspect',  hi/wi);
end
