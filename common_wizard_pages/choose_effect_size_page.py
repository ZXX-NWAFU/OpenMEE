#################
#               #
# George Dietz  #
# CEBM@Brown    #
#               #
#################

import sys
from functools import partial

from PyQt4 import QtCore, QtGui
from PyQt4.Qt import *

from ome_globals import *
import ui_choose_effect_size_page



class ChooseEffectSizePage(QWizardPage, ui_choose_effect_size_page.Ui_choose_effect_size_page):
    def __init__(self, parent=None, add_generic_effect=False, data_type=None, metric=None, var_groups=[]):
        # data_type and metric are default values to (will be selected)
        
        super(ChooseEffectSizePage, self).__init__(parent)
        self.setupUi(self)
        
        self.add_generic_effect = add_generic_effect
        
        # If there is only one variable group, and data_type and metric are
        # None, inherit the group's data type and metric
        if data_type is None and metric is None and len(var_groups)==1:
            print("Data type and metric defaults are None, inheriting from var_group")
            metric = var_groups[0].get_metric()
            data_type = var_groups[0].get_data_type()
            
        self.selected_data_type = data_type
        self.selected_metric = metric    
        
    def initializePage(self):
        # this has to be in initializePage() rather than __init__() because it
        # calls self.wizard().adjustSize() and the wizard doesn't exist yet when
        # __init__() is called
        self._populate_data_type_groupBox()

    def validatePage(self):
        ''' Implements validatePage virtual function of QWizardPage. Called when
        the user clicks 'Next' or 'Finish' to perform last minute validation.
        In this case, we make sure that if the selected data type is
        GENERIC_EFFECT, we display a warning to the user to make sure that the
        variance is normally distributed'''

        generic_effect_selected = self.get_metric() is GENERIC_EFFECT
        if generic_effect_selected:
            generic_effect_string = METRIC_TEXT_SIMPLE[GENERIC_EFFECT]
            button_pressed = QMessageBox.question(
                self,
                QString("Variance normally distributed?"),
                QString("You have selected %s. The %s metric is only valid if"
                    " the variance is normally distributed. Knowing this, do you"
                    " wish to continue with the analysis?\n\nIf the variance is not"
                    " normally distributed, consider transforming your effect"
                    " size and variance to a scale where the variance is normally"
                    " distributed" % (generic_effect_string, generic_effect_string)
                ),
                QMessageBox.Yes|QMessageBox.No,
            )
            if button_pressed == QMessageBox.No:
                return False

        return True
        
        
    def isComplete(self):
        if self.selected_data_type is None:
            return False
        if self.selected_metric is None:
            return False
        if self.selected_metric not in DATA_TYPE_TO_METRICS[self.selected_data_type]:
            return False
        return True
        
    def _populate_data_type_groupBox(self):
        layout = self.data_type_groupBox.layout()
        if layout is None:
            layout = QVBoxLayout()
            self.data_type_groupBox.setLayout(layout)
        
        # clear groupbox first
        self._unfill(layout)
        
        data_type_to_btn = {}
        for data_type in DATA_TYPE_TO_METRICS.keys():
            dt_btn = QRadioButton(DATA_TYPE_TEXT[data_type])
            layout.addWidget(dt_btn)
            # the btn ids will simply be the enumerated data type ids
            QObject.connect(dt_btn, SIGNAL("clicked(bool)"), partial(self._update_data_type_selection, data_type=data_type))
            data_type_to_btn[data_type]=dt_btn
        
        
        if self.selected_data_type in data_type_to_btn.keys():
            self.blockSignals(True)
            btn = data_type_to_btn[self.selected_data_type]
            btn.setChecked(True)
            self._update_data_type_selection(True, data_type=self.selected_data_type)
            self.blockSignals(False)
            
            
        self.wizard().adjustSize()
        
        
        
    def _update_data_type_selection(self, state, data_type):
        if state:
            self.selected_data_type = data_type
            #self.selected_metric = None
            self.emit(SIGNAL("completeChanged()"))
            
        self._populate_effect_size_groupBox()
        self.wizard().adjustSize()
        
    def _populate_effect_size_groupBox(self):
        layout = self.effect_size_groupBox.layout()
        if layout is None:
            layout = QVBoxLayout()
            self.effect_size_groupBox.setLayout(layout)
        
        # clear groupbox layout first
        self._unfill(layout)

        metrics = DATA_TYPE_TO_METRICS[self.selected_data_type]
        
        effect_size_to_btn = {}
        for effect_size in metrics:
            if not self.add_generic_effect:
                if effect_size == GENERIC_EFFECT:
                    continue
            
            btn = QRadioButton(METRIC_TEXT[effect_size])
            layout.addWidget(btn)
            # the buttons ids are simply the effect size ids
            QObject.connect(btn, SIGNAL("clicked(bool)"), partial(self._update_effect_size_selection, effect_size=effect_size))
            effect_size_to_btn[effect_size] = btn
            
            
        if self.selected_metric in effect_size_to_btn.keys():
            self.blockSignals(True)
            btn = effect_size_to_btn[self.selected_metric]
            btn.setChecked(True)
            self._update_effect_size_selection(True, effect_size=self.selected_metric)
            self.blockSignals(False)
    
    def _update_effect_size_selection(self, state, effect_size):
        if state:
            self.selected_metric = effect_size
            self.emit(SIGNAL("completeChanged()"))
    
    #http://www.riverbankcomputing.com/pipermail/pyqt/2009-November/025214.html
    def _unfill(self, layout2delete):
        def deleteItems(layout):
            if layout is not None:
                while layout.count():
                    item = layout.takeAt(0)
                    widget = item.widget()
                    if widget is not None:
                        widget.deleteLater()
                    else:
                        deleteItems(item.layout())
        deleteItems(layout2delete)
    
    
    ############################### Getters ###################################
    
    def get_metric(self):
        return self.selected_metric
    def get_data_type(self):
        return self.selected_data_type
    def get_data_type_and_metric(self):
        return (self.selected_data_type, self.selected_metric)
    
    ##########################################################################
    
    def __str__(self):
        metric_str = "Metric: %s" % METRIC_TEXT[self.get_metric()]
        data_type_str  = "Data Type: %s" % DATA_TYPE_TEXT[self.get_data_type()]
        
        summary = "\n".join([metric_str, data_type_str])
        return summary

def test_page():
    ''' This doesn't really work for testing the page. Don't rely on it '''
    app = QtGui.QApplication(sys.argv)
    choose_effect_size_page = ChooseEffectSizePage(
        parent=None,
        add_generic_effect=True,
        data_type=None,
        metric=None,
        var_groups=[]
    )
    choose_effect_size_page.show()
    sys.exit(app.exec_())
        
# Delete a layout
#import sip
#sip.delete(widget.layout())