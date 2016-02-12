# Special methods for helping out OpenMEE

# Helpers for regression to show categorical covariate means instead of differences

linear.combination <- function(a, rma.results, conf.level=95.0) {
	# a is a matrix describing how to combine the
	# intercept and a difference to get a mean
	#
	# Ex. 'a' matrix:
	#           A B C D
	# intercept 1 0 0 0
	#        x1 1 1 0 0
	#        x2 1 0 1 0
	# 	     x3 1 0 0 1

	alpha <- 1.0-(conf.level/100.0)
	mult <- abs(qnorm(alpha/2.0))
	a <- t(a) # need to transpose for math to be sane

	new_betas  <- t(a) %*% matrix(rma.results$b, ncol=1)
	new_cov   <- t(a) %*% rma.results$vb %*% a
	new_vars <- diag(new_cov)
	new_lowers <- new_betas - mult*sqrt(new_vars)
	new_uppers <- new_betas + mult*sqrt(new_vars)
	new_se     <- sqrt(new_vars)

	res <- data.frame(b=new_betas, ci.lb=new_lowers, ci.ub=new_uppers, se=new_se)
	res
}

adjusted_means_display <- function(rma.results, params, display.data) {

	conf.level <- params$conf.level

	# Generate 'a' matrix
	num.levels = display.data$factor.n.levels[1] # just look at the first covariate for now
	a <- rep(1,num.levels)
	for (one.pos in 2:num.levels) {
		col = c(rep(0,one.pos-1),1,rep(0,num.levels-one.pos))
		a <- c(a,col)
	}
	a <- matrix(a, nrow=num.levels)

	levels <- display.data$levels.display.col
	levels <- levels[levels!='']
	studies <- display.data$studies.display.col
	studies <- studies[studies!='']

	res <- linear.combination(a, rma.results, conf.level)
	res <- c(res, list(levels=levels,
			           studies=studies))
	return(create.adjusted.regression.display(res, params))
}


cond_means_calculation <- function(rma.results, params, reg.data, cat.ref.var.and.levels, cond.means.data) {
	chosen.cov.name = as.character(cond.means.data$chosen.cov.name)
	conf.level <- params$conf.level
	chosen.cov.levels <- cat.ref.var.and.levels[[chosen.cov.name]]

	a <- generate.a.matrix(reg.data, cat.ref.var.and.levels, cond.means.data)
	chosen_pos <- get.chosen.cov.position(chosen.cov.name, reg.data)

	res <- linear.combination(a, rma.results, conf.level)
	result <- list(res=res, chosen.cov.levels=chosen.cov.levels, chosen_pos=chosen_pos, chosen.cov.name=chosen.cov.name)
}


get.chosen.cov.position <- function(chosen.cov.name, reg.data) {
	count <- 0
	for (i in 1:length(reg.data@covariates)) {
		cov <- reg.data@covariates[[i]]
		cov.name <- cov@cov.name
		cov.type <- cov@cov.type


		if (cov.type=="factor") {
			count <- count + 1 # position in categorical covariates
			#cat.cov.names <- c(cat.cov.names, cov.name)
			if (cov.name == chosen.cov.name) chosen.pos <- count
		}
	}
	chosen.pos
}

generate.a.matrix <- function(reg.data, cat.ref.var.and.levels, cond.means.data) {
	#####@@@@@@@@@@ Generate 'a' matrix #########################
	chosen.cov.name = as.character(cond.means.data$chosen.cov.name)
	chosen.cov.levels <- cat.ref.var.and.levels[[chosen.cov.name]]

	# First make a list of continous and catagorical covariates as they appear in the mods array (and a matrix)
	cont.cov.names <- c()
	cat.cov.names <- c()
	for (i in 1:length(reg.data@covariates)) {
		cov <- reg.data@covariates[[i]]
		cov.name <- cov@cov.name
		cov.type <- cov@cov.type

		if (cov.type=="continuous") {
			cont.cov.names <- c(cont.cov.names, cov.name)
		}
		if (cov.type=="factor") {
			cat.cov.names <- c(cat.cov.names, cov.name)
		}
	}

	num.rows <- length(cat.ref.var.and.levels[[chosen.cov.name]])
	a <- cbind(c(), rep(1,num.rows))

	# add in data for continuous variables
	for (cont.name in cont.cov.names) {
		col <- rep(cond.means.data[[cont.name]],num.rows)
		a <- cbind(a,col)
	}

	# add in data for categorical variables
	count = 0
	for (cat.name in cat.cov.names) {
		count = count + 1
		ref.var <- cat.ref.var.and.levels[[cat.name]][[1]]
		n.cols  <- length(cat.ref.var.and.levels[[cat.name]]) - 1 # exclude reference var

		if (cat.name != chosen.cov.name) {
			value   <- cond.means.data[[cat.name]]
			levels <- cat.ref.var.and.levels[[cat.name]]
			levels.min.ref <- levels[2:length(levels)]

			new.row <- (levels.min.ref==value)*1
			block <- matrix(new.row, byrow=TRUE, nrow=num.rows, ncol=length(levels.min.ref))
			a <- cbind(a, block)

		} else { # this is the chosen categorical variable that we stratify over
			chosen_pos = count
			#chosen.cov.levels <- cat.ref.var.and.levels[[cat.name]]
			chosen.level <- chosen.cov.levels[i]
			block <- make.submatrix.for.strat.var(chosen.cov.levels, ref.var)
			a <- cbind(a,block)

		} # end of else

	} # end for

	cat("A matrix", a)
	a
############## End of a matrix generation ################
}

# Makes a subset of an BinaryData or ContinuousData object with the:
# study names
# study years
# point estimates
# standard errors

get.subset <- function(data, rows, make.unique.names=FALSE) {
	data@study.names <- data@study.names[rows]
	data@y <- data@y[rows]
	data@SE <- data@SE[rows]

	if (length(data@covariates) > 0) {
		for (j in 1:length(data@covariates)) {
			# put covariate data into two arrays, for continuous and factor covariates.
			data@covariates[[j]]@cov.vals <- data@covariates[[j]]@cov.vals[rows]
		}
	}

	if (make.unique.names) {
		data@study.names <- as.character(1:length(rows))
	}

	data
}


boot.cond.means.display <- function (omdata, coeffs.and.cis, params, cat.ref.var.and.levels, cond.means.data) {
	cov.data <- extract.cov.data(omdata)
	display.data <- cov.data$display.data
	chosen.cov.name = as.character(cond.means.data$chosen.cov.name)

	levels     <- cat.ref.var.and.levels[[chosen.cov.name]]
	chosen_pos <- get.chosen.cov.position(chosen.cov.name, omdata)

	# Display proper numbers for studies column
	if (chosen_pos-1<1)
		studies.start.index <- 1
	else
		studies.start.index <- sum(display.data$factor.n.levels[1:(chosen_pos-1)])+1
	studies <- display.data$studies.display.col
	studies <- studies[studies!='']
	studies <- studies[studies.start.index:(studies.start.index+length(levels)-1)]


	res <- list(b=coeffs.and.cis$b, ci.lb=coeffs.and.cis$ci.lb, ci.ub=coeffs.and.cis$ci.ub,
				levels=levels, studies=studies,
				chosen.cov.name=chosen.cov.name, cond.means.data=cond.means.data)
	return(create.cond.means.regression.display(res, params, bootstrap=TRUE))
}


cond_means_display <- function(rma.results, params, display.data, reg.data, cat.ref.var.and.levels, cond.means.data) {
	# cat.ref.var.and.levels is a list:
	#      keys: names of covariates
	#      values: vector of ref.value and rest of levels in proper order
	#
	# cond.means.data is a list obtained from python:
	#      keys: chosen.cov.name : name of covariate chosen to stratify over
	#            other covariate names: values chosen for these covariates


	# returns coefficients, uppers, lowers, and se
	cond_means_result <- cond_means_calculation(rma.results, params, reg.data, cat.ref.var.and.levels, cond.means.data)
	res             <- cond_means_result$res
	levels          <- cond_means_result$chosen.cov.levels
	chosen_pos      <- cond_means_result$chosen_pos
	chosen.cov.name <- cond_means_result$chosen.cov.name

	#levels <- display.data$levels.display.col
	#levels <- levels[levels!='']
	#levels <- chosen.cov.levels

	if (chosen_pos-1<1) {
		studies.start.index <- 1
	} else {
		studies.start.index <- sum(display.data$factor.n.levels[1:(chosen_pos-1)])+1
	}
	studies <- display.data$studies.display.col
	studies <- studies[studies!='']
	studies <- studies[studies.start.index:(studies.start.index+length(levels)-1)]


	res <- c(res, list(levels=levels, studies=studies, chosen.cov.name=chosen.cov.name, cond.means.data=cond.means.data)  )
	return(create.cond.means.regression.display(res, params))
}



make.submatrix.for.strat.var <- function(levels, ref) {
	levels.min.ref <- levels[2:length(levels)]
	block = c()
	for (lvl in levels) {
		new.row <- (levels.min.ref == lvl)*1
		block <- rbind(block, new.row)
	}
	block
}


create.cond.means.regression.display <- function(res, params, bootstrap=FALSE) {
	if (bootstrap)
		col.labels <- c("Level", "Studies", "Conditional Means", "Lower bound", "Upper bound")
	else
		col.labels <- c("Level", "Studies", "Conditional Means", "Lower bound", "Upper bound", "Std. error")
	n.rows = length(res$levels)+1

	reg.array <- array(dim=c(n.rows, length(col.labels)), dimnames=list(NULL, col.labels))
	reg.array[1,] <- col.labels
	digits.str <- paste("%.", params$digits, "f", sep="")
	coeffs <- sprintf(digits.str, res$b)
	if (!bootstrap)
		se <- round.display(res$se, digits=params$digits)
	lbs <- sprintf(digits.str, res$ci.lb)
	ubs <- sprintf(digits.str, res$ci.ub)

	# add data to array
	reg.array[2:n.rows, "Level"] <- res$levels
	reg.array[2:n.rows, "Studies"] <- res$studies
	reg.array[2:n.rows, "Conditional Means"] <- coeffs
	if (!bootstrap)
		reg.array[2:n.rows, "Std. error"] <- se
	reg.array[2:n.rows, "Lower bound"] <- lbs
	reg.array[2:n.rows, "Upper bound"] <- ubs

	arrays <- list(arr1=reg.array)
	metric.name <- pretty.metric.name(as.character(params$measure))

	blurb <- paste("\nThese are the conditional means for '",res$chosen.cov.name, "',\nstratified over its levels given the following values for the other covariates:\n", sep="")
	for (name in names(res$cond.means.data)) {
		if (name != 'chosen.cov.name') {
			blurb <- paste(blurb, name, " = ", res$cond.means.data[[name]], "\n", sep="")
		}
	}

	if (bootstrap)
		model.title <- paste("Bootstrapped Meta-Regression-Based Conditional Means\n\nMetric: ", metric.name, "\n", blurb, sep="")
	else
		model.title <- paste("Meta-Regression-Based Conditional Means\n\nMetric: ", metric.name, "\n", blurb, sep="")
	reg.disp <- list("model.title" = model.title, "table.titles" = c("Model Results"), "arrays" = arrays, "MAResults" = res)

	class(reg.disp) <-  "summary.display"
	return(reg.disp)
}



create.adjusted.regression.display <- function(res, params) {
	col.labels <- c("Level", "Studies", "Adjusted Means", "Lower bound", "Upper bound", "Std. error")
	n.rows = length(res$b)+1

	reg.array <- array(dim=c(n.rows, length(col.labels)), dimnames=list(NULL, col.labels))
	reg.array[1,] <- col.labels
	digits.str <- paste("%.", params$digits, "f", sep="")
	coeffs <- sprintf(digits.str, res$b)
	se <- round.display(res$se, digits=params$digits)
	lbs <- sprintf(digits.str, res$ci.lb)
	ubs <- sprintf(digits.str, res$ci.ub)

	# add data to array
	reg.array[2:n.rows, "Level"] <- res$levels
	reg.array[2:n.rows, "Studies"] <- res$studies
	reg.array[2:n.rows, "Adjusted Means"] <- coeffs
	reg.array[2:n.rows, "Std. error"] <- se
	reg.array[2:n.rows, "Lower bound"] <- lbs
	reg.array[2:n.rows, "Upper bound"] <- ubs

	arrays <- list(arr1=reg.array)
	metric.name <- pretty.metric.name(as.character(params$measure))
	model.title <- paste("Meta-Regression Adjusted Means\n\nMetric: ", metric.name, sep="")
	reg.disp <- list("model.title" = model.title, "table.titles" = c("Model Results"), "arrays" = arrays, "MAResults" = res)

	class(reg.disp) <-  "summary.display"
	return(reg.disp)
}



###################### Histogram code #########################

exploratory.plotter <- function(data, params, plot.type) {
	# Main function to call from python side to make a histogram or scatterplot

	plot.data.path = save.exploratory.data(data, params)

	# draw plot & save funnel data
	plot.path = paste(plot.data.path, ".png", sep="")

	if (plot.type=="HISTOGRAM") {
		make.histogram(plot.path, data, params)
		images <- c("Histogram"=plot.path)
		plot_params_paths <- c("Histogram"=plot.data.path)
	}
	else if (plot.type=="SCATTERPLOT") {
		make.scatterplot(plot.path, data, params)
		images <- c("Scatterplot"=plot.path)
		plot_params_paths <- c("Scatterplot"=plot.data.path)
	}
	else
		stop("Unrecognized plot type")

	results <- list(
			images=images,
			plot_params_paths=plot_params_paths
			#References="funnel plot reference placeholder"
	)
}

get.exploratory.params <- function(out.path) {
	# accessor for python to load the stored histogram params
	load(paste(out.path, ".params", sep=""))
	params
}

save.exploratory.data <- function(data, params, out.path=NULL) {
	# save the data, result and plot parameters to a tmp file on disk
	if (is.null(out.path)){
		# by default, we use thecurrent system time as a 'unique enough' filename
		out.path <- paste("r_tmp/",
				as.character(as.numeric(Sys.time())), sep="")
	}

	save(data, file=paste(out.path, ".data", sep=""))
	save(params, file=paste(out.path, ".params", sep=""))
	out.path
}

# FOR SCATTERPLOT OR HISTOGRAM
regenerate.exploratory.plot <- function(out.path, plot.path, plot.type, edited.params=NULL) {
	# Used when saving or editing the plot

	# out.path is the path to r_tmp/{timestamp}* or whatever

	# load data and params in to function workspace
	load(paste(out.path, ".data", sep=""))

	# load the stored params when we are just saving, not editing
	if (is.null(edited.params)) {
		load(paste(out.path, ".params", sep=""))
	}
	else {
		params <- edited.params
		save.exploratory.data(data, params, out.path=out.path)
	}

	if (plot.type=="SCATTERPLOT")
		make.scatterplot(plot.path, data, params)
	else if (plot.type=="HISTOGRAM")
		make.histogram(plot.path, data, params)
	else
		stop("unrecognized plot type")
}
############## End of Histogram code #################################


model.building <- function(data, full.mods, reduced.mods, method, level, digits, btt=NULL) {
	# This is s a thin wrapper to metafor's meta regression functionality
	# in order to let R do the dummy coding for us
	#
	# mods.str: string to be passed to metafor to implement the moderators
	#     e.g. ~ gfactor(alloc)+ablat+gfactor(country)+gfactor(alloc):gfactor(country)
	# mods: list(numeric=c(...numeric moderators...),
	#            categorical=c(...categorical moderators...),
	#            interactions=list("A:B"=c("A","B"),"B:C"=c("B",C"),...)
	#            )
	#     Note that the interaction names should be as they appear in the mods
	#     string formula
	# data: should be a dataframe of the type that metafor likes ie
	# yi and vi for the effect and variance columns
	# slab holds study names
	# the parts that are 'factors' have already been made in to factors with
	# the appropriate reference values

	full.mods.str <- make.mods.str(full.mods)
	reduced.mods.str <- make.mods.str(reduced.mods)

	# obtain regression result rma.uni
	full.res    <- regression.wrapper(data, full.mods.str, method, level, digits,btt)
	reduced.res <- regression.wrapper(data, reduced.mods.str, method, level, digits,btt)

	res <- anova(full.res, reduced.res, digits=digits)

	# temporarily widen console for printing
	old.width <- getOption("width")
	options(width=1000)
	summary.str <- paste(capture.output(res), collapse="\n") # convert print output to a string
	options(width=old.width)

	results <- list(#"images"=images,
			"Summary"=summary.str,
			#"plot_names"=plot.names,
			#"plot_params_paths"=plot.params.paths,
			"res"=res,
			"res.info"=model.building.value.info())
}

model.building.value.info <- function() {
    list(
		fit.stats.f = list(type="vector", description="log-likelihood, deviance, AIC, BIC, and AICc for the full model."),
		fit.stats.r = list(type="vector", description="log-likelihood, deviance, AIC, BIC, and AICc for the reduced model."),
		p.f         = list(type="vector", description="number of parameters in the full model."),
		p.r         = list(type="vector", description="number of parameters in the reduced model."),
		LRT         = list(type="vector", description="likelihood ratio test statistic."),
		pval        = list(type="vector", description="p-value for the likelihood ratio test."),
		QE.f        = list(type="vector", description="test statistic for the test of (residual) heterogeneity from the full model."),
		QE.r        = list(type="vector", description="test statistic for the test of (residual) heterogeneity from the reduced model."),
		tau2.f      = list(type="vector", description="estimated  2 value from the full model."),
		tau2.r      = list(type="vector", description="estimated  2 value from the reduced model."),
		R2          = list(type="vector", description="amount of (residual) heterogeneity in the reduced model that is accounted for in the full model. NA( for fixed-effects models or if the amount of heterogeneity in the reduced model is equal to zero. This can be regarded as a pseudo R2 statistic (Raudenbush, 2009).")
    )
}

rma.mv.value.info <- function() {
	list(
		b         = list(type="matrix", description='estimated coefficients of the model.'),
		se        = list(type="vector", description='standard errors of the coefficients.'),
		zval      = list(type="vector", description='test statistics of the coefficients.'),
		pval      = list(type="vector", description='p-values for the test statistics.'),
		ci.lb     = list(type="vector", description='lower bound of the confidence intervals for the coefficients.'),
		ci.ub     = list(type="vector", description='upper bound of the confidence intervals for the coefficients.'),
		vb        = list(type="matrix", description='variance-covariance matrix of the estimated coefficients.'),
		sigma2    = list(type="vector", description='estimated sigma^2 value(s)'),
		tau2      = list(type="vector", description='estimated taU^2 values'),
		rho       = list(type="vector", description='estimated ρ value(s).'),
		k         = list(type="vector", description='number of studies included in the model.'),
		p         = list(type="vector", description='number of coefficients in the model (including the intercept).'),
		m         = list(type="vector", description='number of coefficients included in the omnibus test of coefficients.'),
		QE        = list(type="matrix", description='test statistic for the test of (residual) heterogeneity.'),
		QEp       = list(type="matrix", description='p-value for the test of (residual) heterogeneity.'),
		QM        = list(type="vector", description='test statistic for the omnibus test of coefficients.'),
		QMp       = list(type="vector", description='p-value for the omnibus test of coefficients.'),
		int.only  = list(type="vector", description='logical that indicates whether the model is an intercept-only model.'),
		yi        = list(type="vector", description='the vector of outcomes'),
		V         = list(type="matrix", description='the corresponding variance-covariance matrix of the sampling errors'),
		X         = list(type="matrix", description='and the model matrix of the model.'),
		fit.stats = list(type="data.frame", description='a list with the log-likelihood, deviance, AIC, BIC, and AICc values')
	)
}


impute <- function(data, m, maxit, defaultMethod) {
  imp.result <- mice(
    data=data,
    m=m,
    maxit=maxit,
    defaultMethod=defaultMethod,
    printFlag=FALSE
  )

	# Plotting code for inspection of imputation results?
#	library(lattice)
#	com <- complete(imp, "long", inc=T)
#	col <- rep(c("blue","red")[1+as.numeric(is.na(imp$data$chl))],6)
#	stripplot(chl~.imp, data=com, jit=TRUE, fac=0.8, col=col, pch=20,
#			+ cex=1.4, xlab="Imputation number")

	imputation.choices <- list()
	for (x in 1:m) {
		imputation.choices[[x]]<-complete(imp.result,x)
	}

	results <- list("res"=imp.result,
				   "Summary"=paste(capture.output(imp.result), collapse="\n"),
				   "imputations"=imputation.choices)

}


multiply.imputed.meta.analysis <- function(imputed.datasets, rma.args, mods=NULL) {
	# Meta analysis with multiply imputed data sets as described here:
	# http://sites.stat.psu.edu/~jls/mifaq.html#howto
	# Also does regression if mods is not NULL

	# imputed datasets
	# rma.args list a list of arguments to the rma.uni function.
	#     includes: method, level, digits
	# same mods argument as in g.meta.regression


	digits = rma.args$digits
	if (!is.null(mods)) {
		# mods.str: string to be passed to metafor to implement the moderators
		#     e.g. ~ gfactor(alloc)+ablat+gfactor(country)+gfactor(alloc):gfactor(country)
		mods.str <- make.mods.str(mods)
	}
	do.analysis <- function(imputed.dataset) {
		if (is.null(mods)) {
			res <- rma.uni(yi,vi, data=imputed.dataset, method=rma.args$method, level=rma.args$level,
					#digits=rma.args$digits
			       )
		} else {
			res <- regression.wrapper(data=imputed.dataset,
					                  mods.str=mods.str,
									  method=rma.args$method,
									  level=rma.args$level,
									  digits=6,
									  btt=NULL)
		}
		res
	}

	# list of res objects that are the result of doing a meta-analysis on the
	# imputed dataset
	res.objects <- lapply(imputed.datasets, do.analysis)

	# Useful for various purposes like getting intercept names and such
	res1 <- res.objects[[1]]

    #### Calculate overall quantities for the multiple imputation
	# Quantities for which we standard errors in the result are:
	# b and tau2, the corresponding standard errors are se and se.tau2
	# b
	b.all <- sapply(res.objects,function(x) {x$b}) # collect b together
	se.all <- sapply(res.objects, function(x) {x$se})

	# v0 (complete data degrees of freedom) for multiple imputation correction (see Rubin 1999)
	v0 = nrow(imputed.datasets[[1]]) - (length(res1$b)-1) # i.e. k-p, subtract 1 from b because intercept included

	if (class(b.all)=="matrix") {
		# Account for b.all and se.all if they are matrices instead of vectors
		nrows <- nrow(res1$b)
		column.names <- c("est", "se", "ci.lb", "ci.ub", "df", "r", "lambda")
		# make empty matrix to store data
		b.data <- matrix(nrow=nrows,
				         ncol=length(column.names),
						 dimnames=list(rownames(res1$b), column.names)
				 )
		for (row in 1:nrows) {
			b.row <- b.all[row,] # row of the b matrix (e.g. all the intercepts of the meta-analyses)
			se.row <- se.all[row,]
			b.row.data <- multiply.imputed.helper(b.row, se.row, v0)
			for (name in column.names) {
				b.data[row, name] <- b.row.data[[name]]
			}
		}
		b.data <- as.data.frame(b.data) # convert to dataframe
	} else { # b.all is just a vector
	    b.data <- multiply.imputed.helper(b.all, se.all, v0)
	}

	# tau2
	tau2.all <- sapply(res.objects, function(x) {x$tau2})
	se.tau2.all <- sapply(res.objects, function(x) {x$se.tau2})
	tau2.data <- multiply.imputed.helper(tau2.all, se.tau2.all, v0)



	# Construct summary
	title <- switch(res1$method,
			        FE="Fixed-Effects Model",
					"Random Effects Model"
					)
	title <- paste("Multiply Imputed", title)
	title <- paste(title, "(k = ", res1$k, "; tau^2 estimator: ", res1$method, ")", sep="")

	summary <- title
	summary <- paste(summary, "\n\n", sep="")
	summary <- paste(summary, "Multiple Imputation Data:\n", "\t# Imputations: ", length(res.objects), "\n", sep="")


	tau2.str <- sprintf("tau^2 (estimated amount of total heterogeneity): %s (SE = %s, CI = [%s,%s], df = %s, r = %s, lambda = %s)",
			            round(tau2.data$est, digits),
				        round(tau2.data$se, digits),
						round(tau2.data$ci.lb, digits),
						round(tau2.data$ci.ub, digits),
						round(tau2.data$df, digits),
						round(tau2.data$r, digits),
						round(tau2.data$lambda, digits))
	tau.str <- sprintf("tau (square root of estimated tau^2 value):       %s", round(sqrt(tau2.data$est), digits) )

	model.results.str <- "\nModel Results:\n\n"
	model.results.df <- data.frame(estimate=b.data$est, se=b.data$se, ci.lb=b.data$ci.lb, ci.ub=b.data$ci.ub, df=b.data$df, r=b.data$r, lambda=b.data$lambda)
	rownames(model.results.df) <- rownames(res1$b)
	model.results.df <- round(model.results.df, digits)
	model.results.str <- paste(model.results.str,
			                   capture.wide.string(model.results.df),
							   "\n", sep="")

	summary <- paste(summary, tau2.str, tau.str, model.results.str, sep="\n")

	# References
	references <- c("Barnard, J. & Rubin, D.B. (1999). Small-sample degrees of freedom with multiple imputation. Biometrika 86, 948-955.",
			"Rubin, D.B. (1987) Multiple Imputation for Nonresponse in Surveys. J. Wiley & Sons, New York.")

	# build res (individual results objects from imputations)
	res <- list()
	for (i in 1:length(res.objects)) {
		key <- paste("result ", i)
		res[[key]] <- capture.wide.string(res.objects[[i]])
	}

	# build res.info
	res.info <- list()
	for (i in 1:length(res.objects)) {
		key <- paste("result ", i)
		res.info[[key]] <- list(type="vector", description=paste('meta analysis result ', i))
	}


	results <- list("Summary"=summary,
			        "res"=res,
					"res.info"=res.info,
					"References"=references)

}

capture.wide.string <- function(x) {
	# temporarily widen console for printing
	old.width <- getOption("width")
	options(width=1000)
	out.str <- paste(capture.output(x), collapse="\n") # convert print output to a string
	options(width=old.width)
	out.str
}

multiply.imputed.helper <- function(x, se, v0) {
	# makes calculations as shown on http://sites.stat.psu.edu/~jls/mifaq.html#howto
	# and outputs results (overall estimate, overall se, and confidence intervals
	# from Student's t-distribution
	# For corrected version: http://support.sas.com/documentation/cdl/en/statug/63033/HTML/default/viewer.htm#statug_mi_sect030.htm

	#
	# Inputs:
	# x is a vector of a scalar quantity of interest (with each element of the
	#   vector being from one of the imputations)
	# se is a vector of standard errors corresponding to x
	# v0 is the complete data degrees of freedom

	m <- length(x) # number of entries
	w = se^2

	# overall estimate
	Qbar <- mean(x)

	# within-imputation variance
	Wbar <- mean(se^2)

	# between imputation variance
	X1 <- 1/(m-1)
	X2 <- sum((x-Qbar)^2)
	B <- X1*X2

	# Total variance
	T <- Wbar + (1+1/m)*B

	# overall standard error
	se.overall <- sqrt(T)

	# The statistic (Q-Qbar)T^-(1/2) is approximately distributed as t with vm degrees of freedom
	### Calculate confidence intervals
	# first calculate degrees of freedom
	X1 <- m-1
	X2 <- Wbar/((1+m^-1)*B)
	vm <- X1*(1+X2)^2 # unadjusted degrees of freedom from Rubin (1987)

	## Other useful statistics
	r <- ((1+m^-1)*B)/Wbar      # rel. increase in variance due to nonresponse
	lambda <- (r+2/(vm+3))/(r+1) # fraction of missing information

	# Calculate adjusted degrees of freedom from Rubin (1999)
	#v0 = ??????
	gamma <- (1+m^-1)*B/T
	vobs <- (1-gamma)*v0*(v0+1)/(v0+3)

	vm <- (1/vm+1/vobs)^-1


 	ci.lb <- Qbar - vm*se.overall # lower confidence limit
	ci.ub <- Qbar + vm*se.overall # upper confidence limit


	data.frame(est=Qbar, se=se.overall, ci.lb=ci.lb, ci.ub=ci.ub, df=vm, r=r, lambda=lambda)
}

combine.imputations.with.dataset <- function(source.dataset, imputations) {
	# source.dataset is a complete (well, missing NAs and such) dataframe (with yi, vi, slab, etc)
	# imputations is a list of dataframes containing imputed covariate values
	# Makes list of datasets with imputed data

	output = list()
	for (i in 1:length(imputations)) {
		imp <- imputations[[i]]
		tmp <- source.dataset
		# copy over imputed data to tmp
		for (cov_name in names(imp)) {
			if (is.factor(source.dataset[[cov_name]])) {
				levels.of.factor <- levels(source.dataset[[cov_name]])
				tmp[[cov_name]] <- factor(imp[[cov_name]], levels=levels.of.factor)
			} else {
				tmp[[cov_name]] <- imp[[cov_name]]
			}
		}
		output[[i]] <- tmp
	}
	output
}


###################### special output for regression ##########################
reg.output.helper <- function(theData, rma.results, model.formula, digits=5) {
	# Adapted from code by M.Lajeunesse by G.Dietz

	# apparently, anova or lm requires rma.results to be global
	rma.results <<- rma.results
	# get model sums of squares from lm based on metafor's tau
	effects.results <- anova(lm(model.formula, weight=1/(vi+rma.results$tau2), data=theData))

	# get summary of the Overall Model
	printModelSummary <- function(ANOVA = effects.results) {
		effectsRange <- nrow(ANOVA) - 1
		model.summary <- data.frame(
				SOURCE = c("model", "residual error", "total"),
				Q = c(
						sum(ANOVA[1:effectsRange,2]),
						ANOVA[effectsRange + 1,2],
						sum(ANOVA[1:effectsRange,2]) + ANOVA[effectsRange + 1,2]
				),
				DF = c(
						sum(ANOVA[1:effectsRange,1]),
						ANOVA[effectsRange + 1,1],
						sum(ANOVA[1:effectsRange,1]) + ANOVA[effectsRange + 1,1]
				),
				P = c(
						1.0 - pchisq(sum(ANOVA[1:effectsRange,2]), df=sum(ANOVA[1:effectsRange,1])),
						1.0 - pchisq(ANOVA[effectsRange + 1,2], df=ANOVA[effectsRange + 1,1]),
						1.0 - pchisq(sum(ANOVA[1:effectsRange,2]) + ANOVA[effectsRange + 1,2], df= sum(ANOVA[1:effectsRange,1]) + ANOVA[effectsRange + 1,1])
				)
		)
		print(model.summary, row.names = FALSE, digits = digits)
	}
	#printModelSummary(effects.results)
	model.summary <- paste(capture.output(printModelSummary(effects.results)), collapse="\n")

	# get summary of the Effect Tests
	printEffectTestsSummary <- function(ANOVA = effects.results) {
		effectsRange <- nrow(ANOVA) - 1
		mainEffects <- rownames(ANOVA[1:effectsRange,])
		model.summary <- data.frame(
				SOURCE = mainEffects,
				Q = ANOVA[1:effectsRange,2],
				DF = ANOVA[1:effectsRange,1],
				P = 1 - pchisq(ANOVA[1:effectsRange,2], ANOVA[1:effectsRange,1])
		)
		print(model.summary, row.names = FALSE, digits = digits)
	}
	#printEffectTestsSummary(effects.results)
	effects.tests.summary <- paste(capture.output(printEffectTestsSummary(effects.results)), collapse="\n")

	list("Model Summary"=model.summary,
	     "Effect Tests Summary"=effects.tests.summary)
}

forest.plot.of.regression.coefficients <- function(coeffs, ci.lb, ci.ub, labels, exclude.intercept=TRUE, filepath=NULL, toFile=TRUE) {
	# b and se are as they come from metafor
	# b is a m*1 matrix with rownames the names of the coefficients
	# se is a vector
	# filepath does not include the extension i.e. ".png" or ".pdf" but just the 'base' filename like /r_tmp/3434847

	n <- length(coeffs)
	if (exclude.intercept) {
		mean <- coeffs[2:n]
	    lower <- ci.lb[2:n]
		upper <- ci.ub[2:n]
		used.labels <- labels[2:n]
		n <- length(coeffs)-1
	} else {
		mean <- coeffs
		lower <- ci.lb
		upper <- ci.ub
		used.labels <- labels
	}

	# make the actual plot
	input.df <- data.frame(x = factor(used.labels,levels=rev(used.labels)), y = mean, ylo = lower, yhi = upper)
	# save input data
	cat(filepath)
	save.coeff.forest.plot.data(input.df, filepath)
	regenerate.coeff.forest.plot(input.df, filepath, "png")
}


g.forest.plot <- function(d){
	# adapted from http://www.r-bloggers.com/forest-plots-using-r-and-ggplot2/
# d is a data frame with 4 columns
# d$x gives variable names
# d$y gives center point
# d$ylo gives lower limits
# d$yhi gives upper limits
	require(ggplot2)
	p <- ggplot(d, aes(x=x, y=y, ymin=ylo, ymax=yhi))+geom_pointrange()+
			coord_flip() + geom_hline(aes(x=0), lty=2) + xlab('Coefficient') + ylab('')

	print(p)
	return(p)
}

regenerate.coeff.forest.plot <- function(input.df, filepath, format) {
	if (format == "png") {
		png(filename=paste(filepath,".png",sep=""))
	} else {
		pdf(file=paste(filepath,".pdf",sep=""))
	}

	g.forest.plot(input.df)
	dev.off()
}

save.coeff.forest.plot.data <- function(input.df, params_path) {
	# save the data, result and plot parameters to a tmp file on disk
	if (is.null(params_path)){
		# by default, we use thecurrent system time as a 'unique enough' filename
		params_path <- paste("r_tmp/",
				as.character(as.numeric(Sys.time())), sep="")
	}

	save(input.df, file=paste(params_path, ".coef_fp_data", sep=""))
	params_path
}
