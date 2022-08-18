require "import"
import "android.widget.*"
import "android.view.*"
import "ok"


activity.setTitle('支付成功页面')
activity.setContentView(loadlayout(ok))
--activity.ActionBar.hide()


print("订单支付成功")