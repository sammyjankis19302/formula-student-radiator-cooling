function write_csv(file, header, data)
%WRITE_CSV  Write a numeric matrix with a header row (works in MATLAB and Octave).
fid = fopen(file, 'w');
if fid < 0
    error('write_csv:open', 'Cannot write %s', file);
end
fprintf(fid, '%s', header{1});
for j = 2:numel(header)
    fprintf(fid, ',%s', header{j});
end
fprintf(fid, '\n');
fmt = [repmat('%.10g,', 1, size(data, 2) - 1), '%.10g\n'];
fprintf(fid, fmt, data.');
fclose(fid);
end
