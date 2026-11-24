function ok = check_simulink()
%CHECK_SIMULINK  Build the Simulink model, run it, and compare it with the script.
%
%   check_simulink() builds ../simulink/cooling_loop.slx with
%   build_cooling_model, simulates the whole endurance event in Simulink, runs
%   simulate_cooling on the same event, and compares the two step by step. It
%   does this twice: for the baseline car, where the fan never comes on, and
%   with poor ducting, where the fan has to switch on. Both use the same solver,
%   step and equations, so they should agree to rounding error. It also saves a
%   picture of the model and of the comparison to ../figures.

here = fileparts(mfilename('fullpath'));
addpath(here);
root = fileparts(here);
figdir = fullfile(root, 'figures');
if ~exist(figdir, 'dir'), mkdir(figdir); end
p = cooling_params();

fprintf('\nBuilding the endurance event ...\n');
cyc = endurance_cycle(p);
fprintf('Building the Simulink model ...\n');
mdl = build_cooling_model(cyc);

p2 = p;
p2.air.eta_ram = 0.15;
cases = {'Baseline', p; 'Poor ducting (ram-air share 0.15)', p2};
ok = true;
keep = cell(size(cases, 1), 4);
for c = 1:size(cases, 1)
    name = cases{c, 1};
    pc = cases{c, 2};
    assignin(get_param(mdl, 'ModelWorkspace'), 'eta_ram', pc.air.eta_ram);
    fprintf('\n%s\n', name);
    fprintf('  Running the Simulink model over %.0f s of the event ...\n', cyc.t(end));
    tic;
    out = sim(mdl);
    t_sim = toc;
    % logged signals come back as N-by-1 or 1-by-1-by-N arrays depending on the
    % block types, so every series is made a column before comparing
    t_s   = as_column(out.get('t_log'));
    T_s   = as_column(out.get('T_log'));
    fan_s = as_column(out.get('fan_log'));
    Q_s   = as_column(out.get('Qrad_log'));
    fprintf('  Running the MATLAB script over the same event ...\n');
    tic;
    res = simulate_cooling(cyc, pc);
    t_scr = toc;
    t_m   = as_column(res.t);
    T_m   = as_column(res.T);
    fan_m = as_column(res.fan);
    Q_m   = as_column(res.Q_rad);

    n = min(numel(T_s), numel(T_m));
    dT   = max(abs(T_s(1:n) - T_m(1:n)));
    dQ   = max(abs(Q_s(1:n) - Q_m(1:n)));
    dtt  = max(abs(t_s(1:n) - t_m(1:n)));
    dfan = sum(abs(fan_s(1:n) - fan_m(1:n)) > 0.5);
    fanon = find(fan_m > 0.5, 1);

    fprintf('  Simulink took %.1f s, the script %.1f s.\n', t_sim, t_scr);
    fprintf('  Time steps compared:              %d of %d\n', n, numel(T_m));
    fprintf('  Peak coolant temperature:         Simulink %.3f degC, script %.3f degC\n', ...
        max(T_s(1:n)), max(T_m));
    if isempty(fanon)
        fprintf('  Fan:                              never switches on\n');
    else
        fprintf('  Fan:                              first switches on at %.1f s\n', t_m(fanon));
    end
    fprintf('  Largest temperature difference:   %.2e K\n', dT);
    fprintf('  Largest radiator-heat difference: %.2e W\n', dQ);
    fprintf('  Fan switch disagreements:         %d steps\n', dfan);
    good = n >= numel(T_m) - 1 && dT < 1e-6 && dQ < 1e-3 && dfan == 0 && dtt < 1e-9;
    if good
        fprintf('  match\n');
    else
        fprintf('  DIFFERENT\n');
    end
    ok = ok && good;
    keep(c, :) = {t_m(1:n), T_m(1:n), T_s(1:n), name};
end
assignin(get_param(mdl, 'ModelWorkspace'), 'eta_ram', p.air.eta_ram);
save_system(mdl);

if ok
    fprintf('\nPASS: Simulink and the MATLAB script give the same answer.\n');
else
    fprintf('\nFAIL: they differ. Please send a screenshot of this window.\n');
end

% picture of the model
pic = fullfile(figdir, 'simulink-model.png');
try
    open_system(mdl);
    print(['-s', mdl], '-dpng', '-r150', pic);
    fprintf('Saved figures/simulink-model.png\n');
catch
    try
        saveas(get_param(mdl, 'Handle'), pic);          % other releases
        fprintf('Saved figures/simulink-model.png\n');
    catch err
        fprintf('Could not save the model picture (%s). Not a problem for the check.\n', err.message);
    end
end

% picture of the comparison
try
    colours = [0.165 0.471 0.839; 0.922 0.408 0.204];
    f = figure('Color', 'w', 'Position', [100 100 900 640]);
    try
        theme(f, 'light');                  % newer releases draw figures dark by default
    catch
    end
    ax1 = subplot(2, 1, 1);
    hold(ax1, 'on');
    h = gobjects(1, 3);
    for c = 1:size(keep, 1)
        h(c) = plot(ax1, keep{c, 1}/60, keep{c, 2}, 'LineWidth', 2.5, 'Color', colours(c, :));
    end
    for c = 1:size(keep, 1)
        h(3) = plot(ax1, keep{c, 1}/60, keep{c, 3}, '--', 'LineWidth', 0.9, 'Color', [0.1 0.1 0.1]);
    end
    light_axes(ax1, keep{1, 1}(end)/60);
    ylabel(ax1, 'Coolant temperature (\circC)', 'Color', 'k');
    title(ax1, 'Same endurance event, two implementations', 'Color', 'k');
    lg = legend(ax1, h, {'Baseline, MATLAB script', 'Poor ducting, MATLAB script', ...
        'Simulink model, both cases (dashed)'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    set(lg, 'Color', 'w', 'TextColor', 'k', 'EdgeColor', [0.85 0.85 0.85]);
    ax2 = subplot(2, 1, 2);
    hold(ax2, 'on');
    worst = 0;
    for c = 1:size(keep, 1)
        diff_c = keep{c, 3} - keep{c, 2};
        worst = max(worst, max(abs(diff_c)));
        plot(ax2, keep{c, 1}/60, diff_c, 'LineWidth', 1.0, 'Color', colours(c, :));
    end
    light_axes(ax2, keep{1, 1}(end)/60);
    xlabel(ax2, 'Time (min)', 'Color', 'k');
    ylabel(ax2, 'Simulink minus script (K)', 'Color', 'k');
    title(ax2, sprintf('Difference between the two (largest %.1g K)', worst), 'Color', 'k');
    print(f, fullfile(figdir, 'simulink-check.png'), '-dpng', '-r150');
    fprintf('Saved figures/simulink-check.png\n');
catch err
    fprintf('Could not save the comparison picture (%s).\n', err.message);
end
end

function x = as_column(x)
x = x(:);
end

function light_axes(ax, t_end)
% light colours whatever the MATLAB theme, so the saved picture reads on GitHub
set(ax, 'Color', 'w', 'XColor', [0.25 0.25 0.25], 'YColor', [0.25 0.25 0.25], ...
    'GridColor', [0.15 0.15 0.15], 'GridAlpha', 0.15, 'Box', 'on', 'XLim', [0 t_end]);
grid(ax, 'on');
end
