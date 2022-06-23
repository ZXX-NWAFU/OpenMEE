OpenMEE
=======

OpenMEE

To run OpenMEE from source, you'll need to install the corresponding dependencies.

You'll need to install the necessary R packages. 
First install the dependencies:

From within a (possibly) sudo-ed R session type:

	> install.packages(c("metafor","lme4","MCMCpack","igraph", "ape", "mice", "Hmisc"))

Next, you'll need to build and install the openmetar packages and altered HSROC (NOT THE ONE FROM CRAN) package and install them. For now, these packages are located in the [OpenMetaAnalyst Repository](https://github.com/bwallace/OpenMeta-analyst-). These package are distributed with the source (NOT the OpenMEE source; the OpenMetaAnalyst source!) under the "src/R" directory of the OMA repository. 

    > R CMD build HSROC
    > R CMD build openmetar
    > sudo R CMD INSTALL HSROC_2.0.5.tar.gz
    > sudo R CMD INSTALL openmetar_1.0.tar.gz

Once R is setup for OpenMeta, you'll need to install Python (we use 2.7) and the necessary libraries. You'll need PyQT (and QT: see http://www.riverbankcomputing.co.uk/software/pyqt/intro) installed -- we use PyQt 4.9; your mileage may vary with other versions. 

Next, install rpy2 (rpy.sourceforge.net/rpy2.html) in Python. Verify that all is well by executing:

    > import rpy2
    > from rpy2 import robjects 

At the Python console.

That should be all you need. Once everything is setup, you can launch the program by typing:

    > python launch.py

At the console. This should fire up the GUI.

important dependency versions:
R      : 3.0.1 (2013-05-16) -- "Good Sport"
metafor: 1.6.0
pyqt4  : 4.10.1

Unit tests
-------------

See https://github.com/gdietz/OpenMEE/wiki/Unit-Testing. 

使用指南：
1.若需要使用请引用此文献
Wallace, B. C., Lajeunesse, M. J., Dietz, G., Dahabreh, I. J., Trikalinos, T. A., Schmid, C. H. and Gurevitch, J. (2017), OpenMEE: Intuitive, open-source software for meta-analysis in ecology and evolutionary biology. Methods Ecol Evol, 8: 941–947. 
![image](https://user-images.githubusercontent.com/107970437/175404980-584e11e2-b132-414e-83d7-8f9ea1c69d0b.png)

2.优缺点：旋钮软件；作图差且无法数据嵌套

3.数据读入，路径非中文，读入后写入ID

4.
