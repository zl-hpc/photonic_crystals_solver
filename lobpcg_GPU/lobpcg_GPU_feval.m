
function [lambda,X,History,i] = lobpcg_GPU_feval(A,B,X,eigNum,resNum,tol,iterMax,precond_A,isGPU)

gnorm = [];
History=[]; % initializations

AX = feval(A,X);
BX = B*X;

lambda = inner_product(X,[],AX)./inner_product(X,[],BX);
%lambda = norm_vectors(X,A)./norm_vectors(X,B);

activeMask = true(1,eigNum);

if isGPU == 1
    %    A = gpuArray(A);
    B = gpuArray(B);
    
    X = gpuArray(X);
    AX = gpuArray(AX);
    BX = gpuArray(BX);
    
    W = gpuArray(X)*0;
    P = gpuArray(X)*0;
    
end
Z = [X,X,X]*0;
AZ = Z;
BZ = Z;

tic
for i = 1 : iterMax
    
    k = i
    
    %%% residual
    W = AX - BX*diag(lambda);
    
    %%%%  error compute
    gnorm = norm_vectors(W,B);
    
    History = [History;gnorm];
    activeMask = full(gnorm > tol)
    activeNum = sum(activeMask);
    %   if activeNum <= resNum
    if sum(activeMask([1 : eigNum-resNum])) == 0
        break;
    end
    
    %%% preconditioning
    
    if ~isempty(precond_A)
        W(:,activeMask) = feval(precond_A,W(:,activeMask));
    end
    
    if i == 1
        W(:,activeMask) = Normalize(W(:,activeMask),B);
    else
        P(:,activeMask) = Normalize(P(:,activeMask),B);
        W(:,activeMask) = Normalize(W(:,activeMask),B);
    end
    
    %%%%%%% compressd eigenvalue problem
    if i == 1
        Z(:,[1 : eigNum + activeNum]) = [X, W(:,activeMask)];
        AZ(:,[1 : eigNum]) = AX;
        AZ(:,[eigNum + 1 : eigNum + activeNum]) = feval(A,Z(:,[eigNum + 1 : eigNum + activeNum]));
        BZ(:,[1 : eigNum + activeNum]) = B*Z(:,[1 : eigNum + activeNum]);
        
        As = Z(:,[1 : eigNum + activeNum])'*AZ(:,[1 : eigNum + activeNum]);
        Bs = Z(:,[1 : eigNum + activeNum])'*BZ(:,[1 : eigNum + activeNum]);
    else
        Z(:,[1 : eigNum + 2*activeNum]) = [X, W(:,activeMask),P(:,activeMask)];
        AZ(:,[1 : eigNum]) = AX;
        AZ(:,[eigNum + 1 : eigNum + 2*activeNum]) = feval(A,Z(:,[eigNum + 1 : eigNum + 2*activeNum]));
        BZ(:,[1 : eigNum + 2*activeNum]) = B*Z(:,[1 : eigNum + 2*activeNum]);
        
        As = Z(:,[1 : eigNum + 2*activeNum])'*AZ(:,[1 : eigNum + 2*activeNum]);
        Bs = Z(:,[1 : eigNum + 2*activeNum])'*BZ(:,[1 : eigNum + 2*activeNum]);
    end
    
    
    Ass = gather(As);
    Bss = gather(Bs);
    [Delta,lambda] = Rayleigh_Ritz_vector(Ass,Bss, eigNum, activeNum,k);
    
    if i == 1
        P = W(:,activeMask)*Delta([eigNum+1 : eigNum + activeNum],:);
    else
        P = W(:,activeMask)*Delta([eigNum + 1 : eigNum + activeNum],:) + ...
            P(:,activeMask)*Delta([eigNum + activeNum + 1 : eigNum + 2*activeNum],:);
    end
    
    X = X*Delta([1:eigNum],:) + P;
    X = Normalize(X,B);
    
    AX = feval(A,X);
    BX = B*X;
    % lambda = inner_product(X,AX)./inner_product(X,BX);
    
    % toc
end
toc


%figure
%   semilogy(History(:,activeMask==0),'.')
%  semilogy(History,'.')

% figure
% semilogy(History)


end










