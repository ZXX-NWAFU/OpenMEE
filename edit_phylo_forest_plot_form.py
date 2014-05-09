#################
#               #
# George Dietz  #
# CEBM@Brown    #
#               #
# This is meant to be used only for editing forest plots generated fromth
#################

from PyQt4.Qt import QObject, SIGNAL
from PyQt4.QtGui import QDialog, QDialogButtonBox

import ui_edit_forest_plot
import python_to_R
from ome_globals import check_plot_bound, seems_sane, add_plot_params

class EditPhyloForestPlotWindow(QDialog, ui_edit_forest_plot.Ui_edit_forest_plot_dlg):

    def __init__(self, img_params_path, png_path, qpixmap_item, title, parent=None):
        super(EditPhyloForestPlotWindow, self).__init__(parent)
        self.setupUi(self)

        # img_params is a string that is the variable
        # name for the R object 
        self.img_params_path = img_params_path

        # if we're unable to load the required R data files,
        # e.g., because they were moved or deleted, then fail
        self.params_d = python_to_R.load_vars_for_plot(
                                    self.img_params_path,
                                    return_params_dict=True,
                                    var_suffixes=("data", "params", "res", "level"))
        self.title = title

        if not self.params_d:
            print "can't load R data for plot editing!"
            return None

        # @TODO reflect current params in UI at launch
        #self.populate_params()
        self.set_ui_values()

        # this is the QPixMap object that houses the
        # plot image
        self.pixmap_item = qpixmap_item

        self.png_path = png_path

        # the handle to the window in which
        # the image is being displayed
        self.results_window = parent

        self.current_param_vals = {}

        # get the button object
        self.apply_button = self.buttonBox.button(QDialogButtonBox.Apply)
        QObject.connect(self.apply_button, SIGNAL("clicked()"), self.regenerate_graph)
        self.populate_params()


    def set_ui_values(self):
        _to_bool = lambda x: True if x=="TRUE" else False

        # first fill in the col strs and show fields
        for col_i in [i+1 for i in xrange(4)]:
            cur_col_edit_box = eval("self.col%s_str_edit" % col_i)
            cur_col_edit_box.setText(str(self.params_d["fp_col%s_str" % col_i]))

            cur_chk_box = eval("self.show_%s" % col_i)
            cur_chk_box.setChecked(self.params_d["fp_show_col%s" % col_i])


        # x-label
        self.x_lbl_le.setText(str(self.params_d["fp_xlabel"]))

        # set the outpath text
        self.image_path.setText(str(self.params_d["fp_outpath"]))

        # bounds
        self.plot_lb_le.setText(str(self.params_d["fp_plot_lb"]))
        self.plot_ub_le.setText(str(self.params_d["fp_plot_ub"]))
        
        # xticks
        self.x_ticks_le.setText(str(self.params_d["fp_xticks"]))

        ##self.show_summary_line.setChecked(_to_bool(self.params_d["fp_show_summary_line"]))
        self.show_summary_line.setChecked(self.params_d["fp_show_summary_line"])    


    def populate_params(self):
        '''
        fill in parameters will current values
        '''
        self.current_param_vals["fp_show_col1"] = self.show_1.isChecked()
        self.current_param_vals["fp_col1_str"] = unicode(self.col1_str_edit.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_show_col2"] = self.show_2.isChecked()
        self.current_param_vals["fp_col2_str"] = unicode(self.col2_str_edit.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_show_col3"] = self.show_3.isChecked()
        self.current_param_vals["fp_col3_str"] = unicode(self.col3_str_edit.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_show_col4"] = self.show_4.isChecked()
        self.current_param_vals["fp_col4_str"] = unicode(self.col4_str_edit.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_xlabel"] = unicode(self.x_lbl_le.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_outpath"] = unicode(self.image_path.text().toUtf8(), "utf-8")
    
        plot_lb = unicode(self.plot_lb_le.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_plot_lb"] = "[default]"
        if plot_lb != "[default]" and check_plot_bound(plot_lb):
            self.current_param_vals["fp_plot_lb"] = plot_lb

        plot_ub = unicode(self.plot_ub_le.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_plot_ub"] = "[default]"
        if plot_ub != "[default]" and check_plot_bound(plot_ub):
            self.current_param_vals["fp_plot_ub"] = plot_ub

        xticks = unicode(self.x_ticks_le.text().toUtf8(), "utf-8")
        self.current_param_vals["fp_xticks"] = "[default]"
        if xticks != "[default]" and seems_sane(xticks):
            self.current_param_vals["fp_xticks"] = xticks
    
        self.current_param_vals["fp_show_summary_line"] = \
                                self.show_summary_line.isChecked()


    def swap_graphic(self):
        new_pixmap = self.results_window.generate_pixmap(self.png_path)
        self.pixmap_item.setPixmap(new_pixmap)
        print "ok -- plot updated in ui"
        # maybe do something pretty here... ?

    def update_plot(self):
        '''
        update the plot parameters to select the user's
        preferences. also writes these to disk.
        '''
        # map the ui elements to the corresponding
        # parameter names in the plot params list
        add_plot_params(self)

        # load things up in the R side

        python_to_R.load_vars_for_plot(self.img_params_path,
                                       var_suffixes=("data", "params", "res", "level"))

        # update relevant variables (on the R side)
        # with new values -- we also write the updated
        # params out to disk here
        python_to_R.update_plot_params(self.current_param_vals,
                                      write_them_out=True,
                                      outpath="%s.params" % self.img_params_path)
        print("out path for params: %s" % "%s.params" % self.img_params_path)

        # now re-generate the plot data on the R side of
        # things
        #python_to_R.regenerate_plot_data(title=self.title)
        ######python_to_R.regenerate_plot_data()


        # finally, actually make the plot and spit it to disk in pdf and png formats
        self.png_path = self.current_param_vals["fp_outpath"]
        #####python_to_R.generate_forest_plot(self.png_path)
        
        python_to_R.regenerate_phylo_forest_plot(img_path=self.png_path,
                                                 params_path=self.img_params_path)
        
        #####python_to_R.write_out_plot_data("%s" % self.img_params_path)

    def regenerate_graph(self):
        # this loads the plot.data into R's environment;
        # the variable name will be plot.data
        self.update_plot()
        self.swap_graphic()

        # will need to tell it to 
        #meta_py_r.generate_forest_plot(self.png_path)
        print "OK!"

   





