function y = cvs(varargin)
% Widely Nonlinear model library of regressors
% Inputs:
% - p: model order (p<=5). Default P = 5
% - q: delay length (vector). Default Q = 5
% Output:
% - y.q: cell array with set of delay tap vectors
% - y.c: cell array with set of binary vectors (conj vs nonconj elements)
% - y.nr: number of regressors
% Version: 2014.02.19

if nargin == 0
    p = []; q = [];
elseif nargin == 1
    p = varargin{1}; q = [];
elseif varargin{1} == 'p'
    p = varargin{2}; q = [];
elseif varargin{1} == 'q'
    p = []; q = varargin{2};
else
    p = varargin{1};
    q = varargin{2};
end

if isempty(p)
    p = 5;
end

if isempty(q)
    q = 5;
end

if p > 25
    disp('Feature not implemented: model order > 25');
    return;
end

Q = q(:);
if length(Q) > p
    disp('Unmatched delay tap vector');
    return;
elseif length(Q) == 1
    Q = repmat(Q, p, 1);
end

y.nr = 0;
ind = 0;

for P = 1:p
    switch P
        case 0
            ind = ind + 1;
            y.q{ind} = 'dc';
            y.c{ind} = 0;
            
        case 1
            for q1 = 0:Q(1)
                ind = ind + 1;
                y.q{ind} = q1;
                y.c{ind} = 0;
            end
            
            for q1 = 0:Q(1)
                ind = ind + 1;
                y.q{ind} = q1;
                y.c{ind} = 1;
            end
            
        case 2
            for q1 = 0:Q(2)
                for q2 = q1:Q(2)
                    ind = ind + 1;
                    y.q{ind} = [q1, q2];
                    y.c{ind} = [0, 0];
                end
            end

            for q1 = 0:Q(2)
                for q2 = 0:Q(2)
                    ind = ind + 1;
                    y.q{ind} = [q1, q2];
                    y.c{ind} = [0, 1];
                end
            end

            for q1 = 0:Q(2)
                for q2 = q1:Q(2)
                    ind = ind + 1;
                    y.q{ind} = [q1, q2];
                    y.c{ind} = [1, 1];
                end
            end

        case 3
            for q1 = 0:Q(3)
                for q2 = q1:Q(3)
                    for q3 = q2:Q(3)
                        ind = ind + 1;
                        y.q{ind} = [q1, q2, q3];
                        y.c{ind} = [0, 0, 0];
                    end
                end
            end

            for q1 = 0:Q(3)
                for q2 = q1:Q(3)
                    for q3 = 0:Q(3)
                        ind = ind + 1;
                        y.q{ind} = [q1, q2, q3];
                        y.c{ind} = [0, 0, 1];
                    end
                end
            end

            for q1 = 0:Q(3)
                for q2 = 0:Q(3)
                    for q3 = q2:Q(3)
                        ind = ind + 1;
                        y.q{ind} = [q1, q2, q3];
                        y.c{ind} = [0, 1, 1];
                    end
                end
            end

            for q1 = 0:Q(3)
                for q2 = q1:Q(3)
                    for q3 = q2:Q(3)
                        ind = ind + 1;
                        y.q{ind} = [q1, q2, q3];
                        y.c{ind} = [1, 1, 1];
                    end
                end
            end

        case 4
            for q1 = 0:Q(4)
                for q2 = q1:Q(4)
                    for q3 = q2:Q(4)
                        for q4 = q3:Q(4)
                            ind = ind + 1;
                            y.q{ind} = [q1, q2, q3, q4];
                            y.c{ind} = [0, 0, 0, 0];
                        end
                    end
                end
            end

            for q1 = 0:Q(4)
                for q2 = q1:Q(4)
                    for q3 = q2:Q(4)
                        for q4 = 0:Q(4)
                            ind = ind + 1;
                            y.q{ind} = [q1, q2, q3, q4];
                            y.c{ind} = [0, 0, 0, 1];
                        end
                    end
                end
            end

            for q1 = 0:Q(4)
                for q2 = q1:Q(4)
                    for q3 = 0:Q(4)
                        for q4 = q3:Q(4)
                            ind = ind + 1;
                            y.q{ind} = [q1, q2, q3, q4];
                            y.c{ind} = [0, 0, 1, 1];
                        end
                    end
                end
            end

            for q1 = 0:Q(4)
                for q2 = 0:Q(4)
                    for q3 = q2:Q(4)
                        for q4 = q3:Q(4)
                            ind = ind + 1;
                            y.q{ind} = [q1, q2, q3, q4];
                            y.c{ind} = [0, 1, 1, 1];
                        end
                    end
                end
            end

            for q1 = 0:Q(4)
                for q2 = q1:Q(4)
                    for q3 = q2:Q(4)
                        for q4 = q3:Q(4)
                            ind = ind + 1;
                            y.q{ind} = [q1, q2, q3, q4];
                            y.c{ind} = [1, 1, 1, 1];
                        end
                    end
                end
            end
            
        case 5
            for q1 = 0:Q(5)
                for q2 = q1:Q(5)
                    for q3 = q2:Q(5)
                        for q4 = q3:Q(5)
                            for q5 = q4:Q(5)
                                ind = ind + 1;
                                y.q{ind} = [q1, q2, q3, q4, q5];
                                y.c{ind} = [0, 0, 0, 0, 0];
                            end
                        end
                    end
                end
            end
            
            for q1 = 0:Q(5)
                for q2 = q1:Q(5)
                    for q3 = q2:Q(5)
                        for q4 = q3:Q(5)
                            for q5 = 0:Q(5)
                                ind = ind + 1;
                                y.q{ind} = [q1, q2, q3, q4, q5];
                                y.c{ind} = [0, 0, 0, 0, 1];
                            end
                        end
                    end
                end
            end
            
            for q1 = 0:Q(5)
                for q2 = q1:Q(5)
                    for q3 = q2:Q(5)
                        for q4 = 0:Q(5)
                            for q5 = q4:Q(5)
                                ind = ind + 1;
                                y.q{ind} = [q1, q2, q3, q4, q5];
                                y.c{ind} = [0, 0, 0, 1, 1];
                            end
                        end
                    end
                end
            end

            for q1 = 0:Q(5)
                for q2 = q1:Q(5)
                    for q3 = 0:Q(5)
                        for q4 = q3:Q(5)
                            for q5 = q4:Q(5)
                                ind = ind + 1;
                                y.q{ind} = [q1, q2, q3, q4, q5];
                                y.c{ind} = [0, 0, 1, 1, 1];
                            end
                        end
                    end
                end
            end

            for q1 = 0:Q(5)
                for q2 = 0:Q(5)
                    for q3 = q2:Q(5)
                        for q4 = q3:Q(5)
                            for q5 = q4:Q(5)
                                ind = ind + 1;
                                y.q{ind} = [q1, q2, q3, q4, q5];
                                y.c{ind} = [0, 1, 1, 1, 1];
                            end
                        end
                    end
                end
            end

            for q1 = 0:Q(5)
                for q2 = q1:Q(5)
                    for q3 = q2:Q(5)
                        for q4 = q3:Q(5)
                            for q5 = q4:Q(5)
                                ind = ind + 1;
                                y.q{ind} = [q1, q2, q3, q4, q5];
                                y.c{ind} = [1, 1, 1, 1, 1];
                            end
                        end
                    end
                end
            end
        case 6
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1];

        case 7
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1, 1];

        case 8
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1, 1, 1];

        case 9
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 10
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 11
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 12
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 13
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 15
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1];

        case 17
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1];

        case 19
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 21
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 23
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        case 25
            ind = ind + 1;
            y.q{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            y.c{ind} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

    end
end

if nargin == 3
    ind = ind + 1;
    y.q{ind} = 'ML';
    y.c{ind} = 0;
end
y.nr = ind;

            
