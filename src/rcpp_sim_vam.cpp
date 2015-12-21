#include "rcpp_sim_vam.h"
#include "rcpp_stop_policy.h"


DataFrame SimVam::get_data() {
    //printf("size:%d,%d\n",(model->time).size(),model->k+1);
    if((model->time).size() > model->k+1) {
        size = model->k+1;
        //printf("data size:%d\n",size);
        (model->time).resize(size);  
        (model->type).resize(size);  
    }
    return DataFrame::create(_["Time"]=model->time,_["Type"]=model->type);
}

DataFrame SimVam::simulate(int nbsim) {
    init(nbsim);

    while(stop_policy->ok()) {//model->k < nbsim) {
        //printf("k=%d\n",model->k);
        //To dynamically increase the size of simulation
        resize();
        //printf("k2=%d\n",model->k);

        //### modAV <- if(Type[k]<0) obj$vam.CM[[1]]$model else obj$vam.PM$models[[obj$data$Type[k]]]
        //# Here, obj$model$k means k-1
        //#print(c(obj$model$Vleft,obj$model$Vright))
        double timePM= 0.0, timeCM = model->models->at(model->idMod)->virtual_age_inverse(model->family->inverse_cumulative_density(model->family->cumulative_density(model->models->at(model->idMod)->virtual_age(model->time[model->k]))-log(runif(1))[0]));
        //TODO: submodels
        int idMod;
        List timeAndTypePM;
        if(model->maintenance_policy != NULL) {
            timeAndTypePM = model->maintenance_policy->update(model); //# Peut-être ajout Vright comme argument de update
            //timeAndTypePM = model->maintenance_policy->update(model->time[model->k]); //# Peut-être ajout Vright comme argument de update

            NumericVector tmp=timeAndTypePM["time"];
            timePM=tmp[0];
        }
        if(model->maintenance_policy == NULL || timeCM < timePM) {
            model->time[model->k + 1]=timeCM;
            model->type[model->k + 1]=-1;
            idMod=0;
        } else {
            model->time[model->k + 1]=timePM;
            NumericVector tmp2=timeAndTypePM["type"];
            int typePM=tmp2[0];
            model->type[model->k + 1]=typePM;
            idMod=timeAndTypePM["type"];
        }
        //printf("k=%d: cm=%lf,pm=%lf\n",model->k,timeCM,timePM);
        //# used in the next update
        model->update_Vleft(false);
        
        //# update the next k, and save model in model too!
        model->models->at(idMod)->update(false);
        
    }

    return get_data();
}

void SimVam::add_stop_policy(List policy) {
    stop_policy=newStopPolicy(this,policy);
}

void SimVam::init(int cache_size_) {
    model->Vright=0;
    model->k=0;
    size=cache_size_+1;cache_size=cache_size_;
    model->idMod=0; // Since no maintenance is possible!
    //model->time=rep(0,size);
    //model->type= rep(1,size);
    (model->time).clear();
    (model->type).clear();
    (model->time).resize(size,0);  
    (model->type).resize(size,1);  
}

#define print_vector(x)                                                                     \
    for (std::vector<double>::const_iterator i = x.begin(); i != x.end(); ++i)   \
    std::cout << *i << ' '; \
    std::cout << "\n";

void SimVam::resize() {
    if(model->k > size-2) {
        //printf("RESIZE!\n");
        //print_vector((model->time))
        //printf("SIZE=%d",size);
        size += cache_size;//printf("->%d\n",size);
        (model->time).resize(size);  
        //print_vector((model->time))
        //printf("model->SIZE=%d\n",(model->time).size());
        (model->type).resize(size);  
    }
}
