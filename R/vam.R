# Simulation: sim.vam

sim.vam <- function(formula) {

	self <- newEnv(sim.vam,formula=formula(formula))

	PersistentRcppObject(self,new = {
		model <- parse.vam.formula(self$formula)
		## specify names of variables inside data.frame
		if(is.null(model$response)) {
			self$response.names <- c("Time","Type")
			self$system.name <- "System"
		} else {
			if(length(model$response)==3)  {
				self$system.name <- model$response[1]
				self$response.names <- tail(model$response,2)
			} else if(length(model$response)==2)  {
				self$system.name <- "System"
				self$response.names <- model$response
			}
		}
		self$formula <- substitute.vam.formula(model=model)
		rcpp <- new(SimVam,model)
		rcpp
	})

	self

}


# TODO: when data provided, complete the data!
simulate.sim.vam <- function(sim, stop.policy = 10, nb.system=1, cache.size=500,as.list=FALSE,data) {

	# To have a first argument more readable
	self <- sim

	rcpp <- self$rcpp()

	self$stop.policy.last <- parse.stop.policy(deparse(substitute(stop.policy)))
	stop.policy <- eval(self$stop.policy.last)
	if(is.numeric(stop.policy)) {
		if(stop.policy == as.integer(stop.policy)) {#integer
			stop.policy <- EndAt(size=stop.policy)
		} else stop.policy <- NULL
	} else if(!inherits(stop.policy,"stop.policy")) {
		stop.policy <- NULL
	}
	if(is.null(stop.policy)) {
		warning("Argument stop.policy is not a proper one!")
		return(invisible(NULL))
	}
	# default cache size
	if(is.null(stop.policy$cache.size)) stop.policy$cache.size <- cache.size

	# add stop.policy object
	rcpp$add_stop_policy(stop.policy)

	if(nb.system>1) {
		# multisystem
		if(as.list) df<-list()
		for(i in 1:nb.system) {
			df2 <- rcpp$simulate(stop.policy$cache.size)[-1,]
			names(df2) <- sim$response.names
			if(as.list) {
				rownames(df2)<-1:nrow(df2)
				df[[i]] <- df2 #rbind(data.frame(Time=0,Type=1),df2)
			} else {
				df2[[sim$system.name]] <- i
				df2<-df2[c(3,1:2)]
				df <- if(i==1) df2 else rbind(df,df2)
			}
		}
	} else {
		df <- rcpp$simulate(stop.policy$cache.size)[-1,]
		names(df) <- sim$response.names
		if(as.list) {rownames(df)<-1:nrow(df);df<-list(df)}
	}
	if(!as.list) {
		rownames(df) <- 1:nrow(df)
		rcpp$set_data(data.frame.to.list.multi.vam(df,names(df))) #if already list, response not used inside data.frame.to.list.multi.vam
	}
	else {
		names(df) <- paste0(sim$system.name,1:length(df))
		rcpp$set_data(unname(df))
	}
	## put the final result transformed as in mle.vam and model.vam to the model
		## return the result as a data.frame
	df
}

# Model part

model.vam <- function(formula,data) {
	if(missing(data)) data<-NULL
	self <- newEnv(model.vam,formula=formula(formula),data=data)

	PersistentRcppObject(self,new = {
		model <- parse.vam.formula(self$formula)
		self$formula <- substitute.vam.formula(model=model)
		if(is.null(self$data)) {## No data
			rcpp <- new(ModelVam,model)
			rcpp
		} else {
			response <- model$response
			data <- data.frame.to.list.multi.vam(self$data,response)
			rcpp <- new(ModelVam,model,data)
			rcpp
		}
	})

	self
}

update.model.vam <- function(model,data) {
	if(!missing(data)) {
		self <- model #to have an argument more readable
		response <- parse.vam.formula(self$formula)$response
		self$data <- data
		data2 <- data.frame.to.list.multi.vam(self$data,response)
		self$rcpp()$set_data(data2)
	}
}

data.frame.to.list.multi.vam <- function(data,response) {
	# return data if it is already only a list!
	if(is.list(data) && !is.data.frame(data)) {
		data.frame(Time=0,Type=1)->tmp
		names(tmp) <- names(data[[1]])
		return(lapply(data,function(df) rbind(tmp,df)))
	}
	if(NCOL(data) > length(response) && ("System" %in% names(data)) ) warning(paste0("WARNING: data has variable 'System' when response in formula does not contain this variable!"))
	# otherwise
	if(length(response)==2) {
		if(length(intersect(response,names(data))) != 2) stop(paste0("Bad response:",response))
		tmp <- data[[response[1]]]
		data2 <- list(data.frame(Time=c(0,tmp[order(tmp)]),Type=c(1,data[[response[2]]][order(tmp)])))
	} else {
		if(length(intersect(response,names(data))) != 3) stop(paste0("Bad response:",response))
		syst0 <- unique(syst<-data[[response[1]]])
		data2 <- list()
		for(i in seq_along(syst0)) {
			df <- data[syst==syst0[i],response]
			tmp <- df[[response[2]]]
			data2[[i]] <- data.frame(Time=c(0,tmp[order(tmp)]),Type=c(1,df[[response[3]]][order(tmp)]))
		}
	}
	data2
}

# TODO: check data
check.data.vam <-function(data,response) {
	if(all(data[[response[[-length(response)]]]])) {

	}
}

mle.vam <- function(formula,data) {
	self <- newEnv(mle.vam,formula=formula(formula),data=data)

	PersistentRcppObject(self,new = {
		model <- parse.vam.formula(self$formula)
		self$formula <- substitute.vam.formula(model=model)
		response <- model$response
		data <- data.frame.to.list.multi.vam(self$data,response)
		rcpp <- new(MLEVam,model,data)
		rcpp
	})

	self
}

# to convert in Rcpp



params.model.vam <- params.sim.vam <- params.mle.vam <- function(self,param) {
	if(missing(param)) {
		 self$rcpp()$get_params()
	} else {
		self$rcpp()$set_params(param)
	}
}

## Useless since stats:::formula.default do that by default
# formula.model.vam <- formula.sim.vam <- function(self) {
# 	self$formula
# }

formula.mle.vam <- function(self,origin=FALSE) {
	form <- substitute.vam.formula(self$formula,coef(self))
	if(origin) list(formula=form,origin=self$formula)
	else form
}

update.mle.vam <- function(mle,data) {
	if(!missing(data)) {
		self <- mle
		model <- parse.vam.formula(self$formula)
		response <- model$response
		self$data <- data
		data2 <- data.frame.to.list.multi.vam(self$data,response)
		self$rcpp()$set_data(data2)
		## estimation has to be computed again!
		self$mle.coef<-NULL
	}
	## with
}

#fonction de LD2
contrast.mle.vam <-function(obj,par0,with_value=TRUE,with_gradient=FALSE,with_hessian=FALSE){
	type=c(with_value,with_gradient,with_hessian)
	rcpp <- obj$rcpp()
	## save the initial param
	if(is.null(obj$par0)) obj$par0 <- params(obj)
	## parameters stuff!
	if(missing(par0))  {
		if("par" %in% names(obj)) {
			param <- obj$par[-1]
			alpha <- obj$par[1]#LD2
		} #not the first run
		else {
			param<-params(obj)[-1] #first run
			alpha<-params(obj)[1]#LD2
		}
	} else if(is.null(par0)) {
		param<-obj$par0[-1]
		alpha<-obj$par0[1]#LD2
	} else {
		param<-par0[-1]
		alpha<-par0[1]#LD2
	}

	if(sum(type)==1) {
		if(type[1]){
			res<-rcpp$contrast(c(alpha,param),FALSE)
		} else if(type[2]){
			res<-rcpp$gradient(c(alpha,param),FALSE)[-1]
		} else if(type[3]){
			res<-rcpp$hessian(c(alpha,param),FALSE)[-1,-1]
		}
	} else {
		res<-list()
		if (type[1]){
			res$contrast<-rcpp$contrast(c(alpha,param),FALSE)
		}
		if(type[2]){
			res$gradient<-rcpp$gradient(c(alpha,param),FALSE)[-1]
		}
		if(type[3]){
			res$hessian<-rcpp$hessian(c(alpha,param),FALSE)[-1,-1]
		}
	}
	res
}

#fonction de LD2
logLikelihood.mle.vam <-function(obj,par0,with_value=TRUE,with_gradient=FALSE,with_hessian=FALSE){
	type=c(with_value,with_gradient,with_hessian)
	rcpp <- obj$rcpp()
	## save the initial param
	if(is.null(obj$par0)) obj$par0 <- params(obj)
	## parameters stuff!
	if(missing(par0))  {
		if("par" %in% names(obj)) {
			param <- obj$par[-1]
			alpha <- obj$par[1]#LD2
		} #not the first run
		else {
			param<-params(obj)[-1] #first run
			alpha<-params(obj)[1]#LD2
		}
	} else if(is.null(par0)) {
		param<-obj$par0[-1]
		alpha<-obj$par0[1]#LD2
	} else {
		param<-par0[-1]
		alpha<-par0[1]#LD2
	}

	if(sum(type)==1) {
		if(type[1]){
			res<-rcpp$contrast(c(alpha,param),TRUE)
		} else if(type[2]){
			res<-rcpp$gradient(c(alpha,param),TRUE)
		} else if(type[3]){
			res<-rcpp$hessian(c(alpha,param),TRUE)
		}
	} else {
		res<-list()
		if (type[1]){
			res$contrast<-rcpp$contrast(c(alpha,param),TRUE)
		}
		if(type[2]){
			res$gradient<-rcpp$gradient(c(alpha,param),TRUE)
		}
		if(type[3]){
			res$hessian<-rcpp$hessian(c(alpha,param),TRUE)
		}
	}
	res
}

# alpha is not considered in the estimation!
run.mle.vam <-function(obj,par0,fixed,method=NULL,verbose=TRUE,...) {
	rcpp <- obj$rcpp()
	## save the initial param
	if(is.null(obj$par0)) obj$par0 <- params(obj)
	## parameters stuff!
	if(missing(par0))  {
		if("par" %in% names(obj)) {
			param <- obj$par[-1]
			alpha <- obj$par[1]#LD2
		} #not the first run
		else {
			param<-params(obj)[-1] #first run
			alpha<-params(obj)[1]#LD2
		}
	} else if(is.null(par0)) {
		param<-obj$par0[-1]
		alpha<-obj$par0[1]#LD2
	} else {
		param<-par0[-1]
		alpha<-par0[1]#LD2
	}
	## fixed and functions stuff!
	if(missing(fixed)) {
		fixed<-rep(FALSE,length(param))
		alpha_fixed<-FALSE#LD2
	} else if(is.numeric(fixed)) {
		fixedInd<-fixed
		fixed<-rep(FALSE,length(param))
		fixed[fixedInd-1]<-TRUE#LD2: ajout du -1
		alpha_fixed<-sum(fixed==1)
	} else {#LD2
		alpha_fixed<-fixed[1]#LD2
		fixed<-fixed[-1]#LD2
	}#LD2


	fn<-function(par) {
		##cat("param->");print(par);print(param[!fixed])
		param[!fixed]<-par
		#cat("param->");print(param)
		## All the commented part allows us to save the param when value is NaN
		#res<-
		-rcpp$contrast(c(alpha,param),alpha_fixed)#LD2
		# if(is.nan(res)) {
		# 	mode_param<-"contrast"
		# 	data_param<- rcpp$get_data(0)
		# 	data_param2 <- obj$data
		# 	save(param,mode_param,data_param,data_param2,file="/Users/remy/tmp/VAM/res.RData")
		# }
		# res
	}

	gr <- function(par) {
	    param[!fixed]<-par
		#cat("param2->");print(param)
		## All the commented part allows us to save the param when value is NaN
		#res <-

	   	(-rcpp$gradient(c(alpha,param),alpha_fixed)[-1])[!fixed]#LD2
		# if(any(is.nan(res))) {
		# 	mode_param<-"gradient"
		# 	save(param,mode_param,file="/Users/remy/tmp/VAM/res.RData")
		# }
		# res
	}

  	## optim stuff!
  	if(is.null(method) || method=="fast") {
    	if(length(param[!fixed])>1) param[!fixed]<-(res <- optim(param[!fixed],fn,gr,method="Ne",...))$par
    	if(is.null(method)) res<-optim(param[!fixed],fn,gr,method="CG",...)
  	} else {
  		res<-optim(param[!fixed],fn,gr,method=method,...)
  	}

  	#fixed tips
  param[!fixed]<-res$par

  if(!alpha_fixed){#LD2
	## complete the scale parameter
	alpha <- rcpp$alpha_est(c(1,param))#LD2
  }#LD2
  res$par<-c(alpha,param)#LD2

  if(verbose) print(res)

  ## save stuff
  obj$fixed <- c(alpha_fixed,fixed)#LD2
  obj$optim<-res
  obj$par<-res$par





  obj$mle.coef <- res$par
  params(obj,obj$mle.coef) #put the result in the c++ part

  ##obj$mle.coef
	obj$optim
}

## Rmk: run.mle.vam is supposed to run many times to get the best estimate!
## Here, par=NULL forces initialisation update but does not ensure that it is the best estimate.
## TODO: try to find a best strategy or many strategies...
coef.mle.vam <- function(obj,par=NULL,method=NULL,verbose=FALSE) {
	if(is.null(obj$mle.coef) || !is.null(par)) {
		res <-run.mle.vam(obj,par,verbose=verbose,method=method)
		if(verbose && obj$optim$convergence>0) cat("convergence=",obj$optim$convergence,"\n",sep="")
	}
	obj$mle.coef
}

# for both sim and mle

parse.vam.formula <- function(formula) {
	if(formula[[1]] != as.name("~")) stop("Argument has to be a formula")
	if(length(formula) == 2) {
		response <- NULL
		cm <- formula[[2]]
	} else {
		tmp <- formula[[2]]
		## simplify parenthesis
		while(tmp[[1]] == as.name("(")) tmp <- tmp[[2]]
		if(tmp[[1]] != as.name("&") && length(tmp) != 3) stop("Left part of formula of the form 'Time & Type'!")
		if(length(tmp[[2]])==3 && tmp[[2]][[1]]==as.name("&")) {
			response <- c(as.character(tmp[[2]][[2]]),as.character(tmp[[2]][[3]]),as.character(tmp[[3]]))
		} else response <- c(as.character(tmp[[2]]),as.character(tmp[[3]]))
		cm <- formula[[3]]
	}
	## simplify parenthesis
	while(cm[[1]] == as.name("(")) cm <- cm[[2]]
	pms <- list()
	policy <- NULL
	if(there.is.pm <- (cm[[1]] == as.name("&"))) { # there is a PM part
		pm <- cm[[3]]
		cm <- cm[[2]]
		# deal with PM part
		if(pm[[1]] == as.name("(")) {
			pm <- pm[[2]]
			if(pm[[1]] != as.name("|")) {
				## Case: No maintenance policy
				#stop("Need a policy to manage Preventive Maintenance")
				policy <- NULL
			} else {
				policy <- pm[[3]]
				if(policy[[1]] == as.name("*")) {
					## Case: Composition of maintenance policies
					# recursive function to detect maintenance policies
					run.over.policies<-function(p) {
						if(p[[1]] == as.name("*")) {
							run.over.policies(p[[2]])
							run.over.policies(p[[3]])
						} else if(is.name(p[[1]])) {
							p[[1]] <- as.name(paste0(as.character(p[[1]]),".maintenance.policy"))
							policies <<- c(policies,list(p))
						}
					}
					## init policies and
					policies <- list()
					run.over.policies(policy)
					## print(policies)
					policy <- policies ##[[1]]
				} else if(is.name(policy[[1]])) {
					## Case: One maintenance policy
					policy[[1]] <- as.name(paste0(as.character(policy[[1]]),".maintenance.policy"))
				}

				# PMs
				pm <- pm[[2]]
			}
			# parser for pm
			parse.pm <- function(pm) {
				if(is.name(pm[[1]])) {
					pm[[1]] <- as.name(paste0(as.character(pm[[1]]),".va.model"))
				}
				pm
			}
			cpt.pms <- 0
			while(pm[[1]] == as.name("+") ) {
				if(length(pm) == 3) {
					pms[[cpt.pms <- cpt.pms + 1]] <- parse.pm(pm[[3]])
					pm <- pm[[2]]
				}
			}
			pms[[cpt.pms <- cpt.pms + 1]] <- parse.pm(pm)
		} else stop("Need parenthesis around the Preventive Maintenance terms")
	}
	# deal with CM PART
	cms <- list()

	# parser for cm
	parse.cm <- function(cm) {
		# print(there.is.pm)
		# print(cm)
		if(there.is.pm) {
			if(cm[[1]] == as.name("(")) cm <- cm[[2]]
			else stop("CM needs a family!")
		}
		if(cm[[1]] != as.name("|")) stop("CM needs a family!")
		family <- cm[[3]]
		if(is.name(family[[1]])) {
			family[[1]] <- as.name(paste0(as.character(family[[1]]),".family.cm"))
		}
		cm <- cm[[2]]
		if(is.name(cm[[1]])) {
			cm[[1]] <- as.name(paste0(as.character(cm[[1]]),".va.model"))
		}
		list(model=cm,family=family)
	}
	cpt.cms <- 0
	while( cm[[1]] == as.name("+") ) {
		if(length(cm) == 3) {
			cms[[cpt.cms <- cpt.cms + 1]] <- parse.cm(cm[[3]])
			cm <- cm[[2]]
		}
	}
	cms[[cpt.cms <- cpt.cms + 1]] <- parse.cm(cm)

	convert.family <- function(fam) {
		list(
				name=as.character(fam[[1]]),
				params=sapply(fam[-1],function(e) as.vector(eval(e)))
				## instead of : params=sapply(cm$family[-1],as.vector)
				## which does not work with negative real since element of tmp[-1] interpreted as call!
		)
	}
	convert.pm <- function(pm) {
		n_pip<-c()
		if(length(pm)>1){
			for(i in 2:length(pm)){
				if((length(pm[[i]])==3)&&(pm[[i]][[1]]==as.name("|"))) {
					n_pip<-c(n_pip,i)
				}
			}
		}
		if(length(n_pip)==0) {
			list(
				name=as.character(pm[[1]]),
				params=as.vector(if(length(pm)==1) numeric(0) else sapply(pm[2:length(pm)],function(e) as.vector(eval(e))))
			)
		} else if(length(n_pip)==1) {
			if(n_pip<(length(pm)-1)) {
				stop("Maximum two arguments after a | in a maintenance effect!")
			} else if(n_pip == length(pm)) {
				if( typeof(tryCatch( as.double(eval(pm[[length(pm)]][[3]])) ,error=function(e){FALSE},finally=function(e){TRUE}))!="logical"){
	  				if((round(eval(pm[[length(pm)]][[3]])) != eval(pm[[length(pm)]][[3]]))||(round(eval(pm[[length(pm)]][[3]]))<=0)) {
	  					stop("Memory argument of a maintenance model has to be a strictly positive integer!")
	  				} else {
	  	  				list(
									name=as.character(pm[[1]]),
									params=as.vector(if(length(pm)==2) as.vector(eval(pm[[2]][[2]])) else c(sapply(pm[2:(length(pm)-1)],function(e) as.vector(eval(e))),as.vector(eval(pm[[length(pm)]][[2]])))),
									m=as.integer(eval(pm[[length(pm)]][[3]]))
		  					)
						}
	  			} else {
	  				list(
							name=as.character(pm[[1]]),
							params=as.vector(if(length(pm)==2) as.vector(eval(pm[[2]][[2]])) else c(sapply(pm[2:(length(pm)-1)],function(e) as.vector(eval(e))),as.vector(eval(pm[[length(pm)]][[2]])))),
							extra=as.character(pm[[length(pm)]][[3]])
						)
	  			}
			} else {
				if( typeof(tryCatch( as.double(eval(pm[[length(pm)-1]][[3]])) ,error=function(e){FALSE},finally=function(e){TRUE}))!="logical"){
  				if((round(eval(pm[[length(pm)-1]][[3]]))!=eval(pm[[length(pm)-1]][[3]]))||(round(eval(pm[[length(pm)-1]][[3]]))<0)) {
  					stop("Memory argument of a maintenance model has to be a positive integer!")
  				} else {
  	  				list(
								name=as.character(pm[[1]]),
								params=as.vector(if(length(pm)==3) as.vector(eval(pm[[2]][[2]])) else c(sapply(pm[2:(length(pm)-2)],function(e) as.vector(eval(e))),as.vector(eval(pm[[length(pm)-1]][[2]])))),
								m=as.integer(eval(pm[[length(pm)-1]][[3]])),
								extra=as.character(pm[[length(pm)]])
	  					)
					}
				} else {
					if( typeof(tryCatch( as.double(eval(pm[[length(pm)]])) ,error=function(e){FALSE},finally=function(e){TRUE}))=="logical"){
						stop("At least one of the two argument of maintenance model after a | must be a memory that is to say a non negative positive integer!")
					} else {
						if((round(eval(pm[[length(pm)]]))!=eval(pm[[length(pm)]]))||(round(eval(pm[[length(pm)]]))<0)) {
	  						stop("Memory argument of a maintenance model has to be a positive integer!")
	  					} else {
	  	  					list(
								name=as.character(pm[[1]]),
								params=as.vector(if(length(pm)==3) as.vector(eval(pm[[2]][[2]])) else c(sapply(pm[2:(length(pm)-2)],function(e) as.vector(eval(e))),as.vector(eval(pm[[length(pm)-1]][[2]])))),
								m=as.integer(eval(pm[[length(pm)]])),
								extra=as.character(pm[[length(pm)-1]][[3]])
		  					)
	  	  				}
					}

				}
			}
		} else {
			stop("Maximum one | in a maintenance effect!")
		}



	 #  if((length(pm)==1)||(pm[[length(pm)]][[1]]!=as.name("|"))) {
		# list(
		# 	name=as.character(pm[[1]]),
		# 	params=as.vector(if(length(pm)==1) numeric(0) else sapply(pm[2:length(pm)],function(e) as.vector(eval(e))))
		# )
	 #  } else if ( typeof(tryCatch( as.double(eval(pm[[length(pm)]][[3]])) ,error=function(e){FALSE},finally=function(e){TRUE}))!="logical"){
	 #  	if((round(eval(pm[[length(pm)]][[3]]))!=eval(pm[[length(pm)]][[3]]))||(round(eval(pm[[length(pm)]][[3]]))<0)) {
	 #  		stop("Memory argument of a maintenance model has to be a positive integer!")
	 #  	} else {
	 #  	  list(
		# 	name=as.character(pm[[1]]),
		# 	params=as.vector(if(length(pm)==2) pm[[2]][[2]] else c(sapply(pm[2:(length(pm)-1)],function(e) as.vector(eval(e))),as.vector(eval(pm[[length(pm)]][[2]])))),
		# 	m=as.integer(eval(pm[[length(pm)]][[3]]))
		#   )
		# }
	 #  }	else {
	 #  	list(
		# 	name=as.character(pm[[1]]),
		# 	params=as.vector(if(length(pm)==2) pm[[2]][[2]] else c(sapply(pm[2:(length(pm)-1)],function(e) as.vector(eval(e))),as.vector(eval(pm[[length(pm)]][[2]])))),
		# 	extra=as.character(pm[[length(pm)]][[3]])
		# )
	 #  }
	}
	convert.mp <- function(mp) {#maintenance policy
		if(is.null(mp)) list(name="None")
		else if(is.list(mp)) {
			list(name="MaintenancePolicyList",policies=lapply(mp,convert.mp))
		}
		else {

			## The function defining the maintenance policy
			## (registered in maintenance-policy-register.R or in any other R file)
			mp.fct <- eval(mp[[1]])
			## params used in the call mp
			pars <- as.list(match.call(mp.fct,mp))[-1]

			## Default values are then automatically completed using declaration of maintenance policy
			pars.default <- (as.list(mp.fct)->tmp)[-length(tmp)]
			pars.default <- pars.default[sapply(pars.default,function(e) nchar(as.character(e)))!=0]
			for(e in names(pars.default)) if(is.null(pars[[e]])) pars[[e]] <- pars.default[[e]]

			##print(list(pars=pars))

			## deal with model parameter which has a specific treatment
			mod <- NULL
			if(!is.null(pars[["model"]])) {
				mod <- rcpp(eval(pars[["model"]]))
				pars[["model"]] <- NULL
			}

			res <- list(
				name=as.character(mp[[1]]),
				params=lapply(pars,eval)
			)
			res[["with.model"]] <- !is.null(mod)
			if(!is.null(mod)) res[["model"]] <- mod
			res
		}
	}


	res<-list(
		response=response,
		models=c(list(convert.pm(cms[[1]]$model)),lapply(pms[rev(seq(pms))],convert.pm)),
		family=convert.family(cms[[1]]$family),
		pm.policy=convert.mp(policy)
	)

	res$max_memory <- max(1,unlist(sapply(res$models,function(e) e$m)),na.rm=TRUE)
	res

}

# use substitute coef in vam formula
substitute.vam.formula <- function(formula,coef,model) {
	if(missing(model)) model <- parse.vam.formula(formula)
	if(missing(coef)) coef <- c(model$family$params,sapply(model$models,function(m) m$params))
	nb_paramsFamily <- length(model$family$params)
	nb_paramsCM <- length(model$models[[1]]$params)
	nb_paramsPM <- sapply(model$models[-1],function(m) length(m$params))
	form <- paste0(
						paste(model$response,collapse=" & "),
						"~ (",
							strsplit(model$models[[1]]$name,"\\.")[[1]][1],
							"(",
							paste(coef[nb_paramsFamily+(1:nb_paramsCM)],collapse=","),
							if(!is.null(model$models[[1]]$m) || !is.null(model$models[[1]]$extra)) {
								extra <- c()
								if(!is.null(model$models[[1]]$extra)) extra <- c(extra,model$models[[1]]$extra)
								if(!is.null(model$models[[1]]$m)) extra <- c(extra,model$models[[1]]$m)
								paste0("|",paste(extra,collapse=","))
							} else "",
							")",
						"|",
							strsplit(model$family$name,"\\.")[[1]][1],
							"(",
							paste(coef[1:nb_paramsFamily],collapse=","),
							")",
						")"
					)
	if(length(model$models)>1) {
		pms <- model$models[-1]
		form <- paste0(form,
							" & (",
							paste(
								sapply(seq(pms),function(i) {
									paste0(
										strsplit(pms[[i]]$name,"\\.")[[1]][1],
										"(",
										paste(coef[nb_paramsFamily+nb_paramsCM+ifelse(i>1,sum(nb_paramsPM[1:(i-1)]),0)+(1:nb_paramsPM[i])],collapse=","),
										if(!is.null(pms[[i]]$m) || !is.null(pms[[i]]$extra)) {
											extra <- c()
											if(!is.null(pms[[i]]$extra)) extra <- c(extra,pms[[i]]$extra)
											if(!is.null(pms[[i]]$m)) extra <- c(extra,pms[[i]]$m)
											paste0("|",paste(extra,collapse=","))
										} else "",
										")"
									)
								}),
								collapse=" + "
							),
							")"
						)
	}
	form <- eval(parse(text=form),envir=globalenv())
	form
}
