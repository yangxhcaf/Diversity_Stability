# Multispecies, spatially implicit IPM
# This version makes it possible to assume "no overlap"
# for intraspecific competition only or intra- and interspecific competition

# ATT 8/26/14
outfile1="ipm_cover.csv"
outfile2="stable_size.csv"
# obsClimateFile="Climate.csv"
perturbPpt=F
perturbTemp=F
# climYrSave=read.csv("climYears.csv")  # use same sequence of years used for observed run
# randYrSave=read.csv("randYears.csv")
A=10000 #Area of 100cm x 100cm quadrat
tlimit=2000 ## number of years to simulate
burn.in=1000    # years to cut before calculations
sppList=c("ARTR","HECO","POSE","PSSP")
bigM=c(75,75,50,50)     #Set matrix dimension for each species
maxSize=c(3000,202,260,225)    # in cm^2: PSSP=225 HECO=202  POSE=260  ARTR=3000  # minSize=0.2  cm^2
Nyrs=22
doGroup=NA  # NA for spatial avg., values 1-6 for a specific group
constant=F  
NoOverlap.Inter=F
compScale=F
setwd(dir = "../")
#============================================================
# (I) LOAD VITAL RATE PARAMETERS & FUNCTIONS
#============================================================
Nspp=length(sppList)

# set up survival parameters and function
source("./survival/import2ipm_noOverlap.r")
# set up growth parameters and function
source("./growth/import2ipm_noOverlap.r")
# set up recruitment parameters and function
source("./recruitment/import2ipm.r")

#============================================================================================#
# (II) Simulation length, Matrix size and initial vectors
#============================================================================================#

v=v.r=b.r=expv=Cr=WmatG=WmatS=list(4)
h=r.L=r.U=Ctot=numeric(4)
for(i in 1:Nspp){
  
  # minimum (0.9*minimum size from data) and maximum sizes (1.1*maximum size from data)
  L=log(0.2)
  U=log(maxSize[i])*1.1     
  
  # boundary points b and mesh points y. Note: b chops up the size interval (L-U) into bigM-equal-sized portions.
  b = L+c(0:bigM[i])*(U-L)/bigM[i] 
  
  # v calculates the middle of each n-equal-sized portion.
  v[[i]] = 0.5*(b[1:bigM[i]]+b[2:(bigM[i]+1)])
  
  # step size for midpoint rule. (see equations 4 and 5 in Ellner and Rees (2006) Am Nat.)
  h[i] = v[[i]][2]-v[[i]][1]  
  
  # variables for Wr approximation
  b.r[[i]]=sqrt(exp(b)/pi)
  v.r[[i]]=sqrt(exp(v[[i]])/pi)
  expv[[i]]=exp(v[[i]])
  r.L[i] = sqrt(exp(L)/pi)
  r.U[i] = sqrt(exp(U)/pi)
  WmatG[[i]]=matrix(NA,length(v.r[[i]]),Nspp)  # storage of size-specific W values for each focal species
  WmatS[[i]]=matrix(NA,length(v.r[[i]]),Nspp)
  
  
} # next species
tmp=range(v.r)
size.range=seq(tmp[1],tmp[2],length=50) # range across all possible sizes

#============================================================================================#
# (III) Utility functions
#============================================================================================#

# load the necessary libraries
library(boot)
library(mvtnorm)
library(msm)
library(statmod)  

## combined kernel
make.K.values=function(v,u,muWG,muWS, #state variables
                       Rpars,rpa,Gpars,Spars,doYear,doSpp){  #growth arguments
  f(v,u,Rpars,rpa,doSpp)+S(u,muWS,Spars,doYear,doSpp)*G(v,u,muWG,Gpars,doYear,doSpp) 
}

# Function to make iteration matrix based only on mean crowding
make.K.matrix=function(v,muWG,muWS,Rpars,rpa,Gpars,Spars,doYear,doSpp) {
  muWG=expandW(v,v,muWG)
  muWS=expandW(v,v,muWS)
  
  K.matrix=outer(v,v,make.K.values,muWG,muWS,Rpars,rpa,Gpars,Spars,doYear,doSpp)
  return(h[doSpp]*K.matrix)
}

# Function to format the W matrix for the outer product
expandW=function(v,u,W){
  if(dim(W)[1]!=length(u)) stop("Check size of W")
  Nspp=dim(W)[2]
  W=as.vector(W)
  W=matrix(W,length(W),ncol=length(v))
  W=as.vector(t(W))
  W=matrix(W,nrow=length(u)*length(v),ncol=Nspp)
  return(W)
}


# Function to calculate size-dependent crowding, assuming no overlap
wrijG=function(r,i,j){
  return(2*pi*integrate(function(z) z*exp(-alphaG[i,j]*(z^2))*Cr[[j]](z-r),r,r+r.U[j])$value+
           pi*Ctot[j]*exp(-alphaG[i,j]*((r+r.U[j])^2))/alphaG[i,j]);   
}
WrijG=Vectorize(wrijG,vectorize.args="r")

wrijS=function(r,i,j){
  return(2*pi*integrate(function(z) z*exp(-alphaS[i,j]*(z^2))*Cr[[j]](z-r),r,r+r.U[j])$value+
           pi*Ctot[j]*exp(-alphaS[i,j]*((r+r.U[j])^2))/alphaS[i,j]);   
}
WrijS=Vectorize(wrijS,vectorize.args="r")


# Function to sum total cover of each species
sumCover=function(v,nt,h,A){
   out=lapply(1:Nspp,function(i,v,nt,h,A) h[i]*sum(nt[[i]]*exp(v[[i]]))/A,v=v,nt=nt,h=h,A=A)
   return(unlist(out))
} 

# Function to sum total density of each species
sumN=function(nt,h){
   out=lapply(1:Nspp,function(i,nt,h) h[i]*sum(nt[[i]]),nt=nt,h=h)
   return(unlist(out))
}

# Function to calculate size variance of each species
varN=function(v,nt,h,Xbar,N){
   out=lapply(1:Nspp,function(i,v,nt,h,Xbar,N) h[i]*sum((exp(v[[i]]-Xbar[i])^2)*nt[[i]])/N[i],v=v,nt=nt,h=h,Xbar=Xbar,N=N)
   return(unlist(out))
}  
              
# Function to do an image plot of a matrix in the usual orientation, A(1,1) at top left  
matrix.image=function(x,y,A,col=topo.colors(100),...) {
	nx=length(x); ny=length(y); 
	x1=c(1.5*x[1]-0.5*x[2],1.5*x[nx]-0.5*x[nx-1]); 
	y1=c(1.5*y[1]-0.5*y[2],1.5*y[ny]-0.5*y[ny-1]); 
	image(list(x=x,y=y,z=t(A)),xlim=x1,ylim=rev(y1),col=col,bty="u",...);  
}

#============================================================================================#
# (IV) Calculate the equilibrium areas.
#============================================================================================# 

## initial population density vector
nt=v
for(i in 1:Nspp) nt[[i]][]=0.1
nt[[1]][] <- 0
nt[[4]][] <- 0
new.nt=nt
## initial population density vector

# set up matrix to record cover
covSave = matrix(NA,tlimit,Nspp)
covSave[1,]=sumCover(v,nt,h,A)

# set up list to store size distributions
sizeSave=list(NULL)
for(i in 1:Nspp){
  sizeSave[[i]]=matrix(NA,length(v[[i]]),(tlimit))
  sizeSave[[i]][,1]=nt[[i]]/sum(nt[[i]])
}

# initial densities 
Nsave=matrix(NA,tlimit,Nspp)
Nsave[1,]=sumN(nt,h)

yrSave=rep(NA,tlimit)
for (i in 2:(tlimit)){
  
  #draw from observed year effects
  allYrs=c(1:Nyrs)
  doYear=sample(allYrs,1)
  yrSave[i]=doYear
  
  #get recruits per area
  cover=covSave[i-1,]; N=Nsave[i-1,]
  rpa=get.rpa(Rpars,cover,doYear)
  
  #calculate size-specific crowding
  alphaG=Gpars$alpha 
  alphaS=Spars$alpha 
  
  
  if(NoOverlap.Inter==F){#T: heterospecific genets cannot overlap; F: overlap allowed
    for(ii in 1:Nspp){ 
      # first do all overlap W's
      Xbar=cover*A/N       # multiply by A to get cover back in cm^2
      varX=varN(v,nt,h,Xbar,N) 
      
      muWG = pi*Xbar*N/(A*alphaG[ii,])
      muWS = pi*Xbar*N/(A*alphaS[ii,])
      
      muWG[is.na(muWG)]=0
      muWS[is.na(muWS)]=0
      
      WmatG[[ii]]=matrix(muWG,nrow=length(v[[ii]]),ncol=Nspp,byrow=T)
      WmatS[[ii]]=matrix(muWS,nrow=length(v[[ii]]),ncol=Nspp,byrow=T)
      
      # now do conspecific no overlap W
      Ctot[ii]=h[ii]*sum(expv[[ii]]*nt[[ii]]) 
      Cr[[ii]]=splinefun(b.r[[ii]],h[ii]*c(0,cumsum(expv[[ii]]*nt[[ii]])),method="natural")
      
      WmatG[[ii]][,ii]=WrijG(v.r[[ii]],ii,ii)/A
      WmatS[[ii]][,ii]=WrijS(v.r[[ii]],ii,ii)/A
    }
  }else{
    for(ii in 1:Nspp){
      Ctot[ii]=h[ii]*sum(expv[[ii]]*nt[[ii]]) 
      Cr[[ii]]=splinefun(b.r[[ii]],h[ii]*c(0,cumsum(expv[[ii]]*nt[[ii]])),method="natural") 
    }
    for(jj in 1:Nspp){ 
      
      WfunG=splinefun(size.range,WrijG(size.range,jj,jj))
      WfunS=splinefun(size.range,WrijS(size.range,jj,jj))
      
      for(ii in 1:Nspp) { 
        WmatG[[ii]][,jj]=WfunG(v.r[[ii]])/A 
        WmatS[[ii]][,jj]=WfunS(v.r[[ii]])/A 
      }
    }
    
  } # end NoOverlap if
  
  for(doSpp in 1:Nspp){  
    if(cover[doSpp]>0){    
      # make kernels and project
      K.matrix=make.K.matrix(v[[doSpp]],WmatG[[doSpp]],WmatS[[doSpp]],Rpars,rpa,Gpars,Spars,doYear,doSpp)	
      new.nt[[doSpp]]=K.matrix%*%nt[[doSpp]] 
      sizeSave[[doSpp]][,i]=new.nt[[doSpp]]/sum(new.nt[[doSpp]])  
    }    
  } # next species
  
  nt=new.nt   
  covSave[i,]=sumCover(v,nt,h,A)  # store the cover as cm^2/cm^2
  Nsave[i,]=sumN(nt,h)
  
  print(i)
  flush.console()
  
  if(sum(is.na(nt))>0) browser()  
} # next time step

outSave <- covSave[(burn.in+1):tlimit,]
colnames(outSave) <- sppList
saveRDS(outSave, file = "./richnessSims/output/HECO-POSE_sims.rds")



