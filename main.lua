require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "layout"
import "android.widget.Button"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.widget.EditText"
import "android.widget.ImageView"
import "android.app.AlertDialog"
import "android.widget.ImageButton"
import "android.content.ComponentName"
import "java.lang.String"
import "com.androlua.Http"
import "com.androlua.LuaWebView"
import "java.security.MessageDigest"
import "java.io.FileOutputStream"
import "android.graphics.BitmapFactory"
import "java.io.File"
import "com.androlua.Ticker"
import "android.graphics.Bitmap"
import "android.content.Intent"
import "android.content.*"
import "android.graphics.BitmapFactory"
import "com.android.qrcode.*"
import "cjson"


--[[
  @author 十年 QQ：1614790395 email：shiniana@qq.com
  lua/alua对接V免签 混合开发功能实现
  含创建订单 查询订单信息 查询订单状态
  检测监控端状态 订单关闭 客户端支付回调
  监控端下载位于：https://github.com/shinian-a/Vmq-App
]]


activity.setTitle('V免签调用API_Pro')
activity.setContentView(loadlayout(layout))
activity.ActionBar.hide()

function MD5(str)
  import "java.security.MessageDigest"
  md5 = MessageDigest.getInstance("MD5")
  local bytes = md5.digest(String(str).getBytes())
  local result = ""
  for i=0,#bytes-1 do
    local temp = string.format("%02x",(bytes[i] & 0xff))
    result =result..temp
  end
  return result
end

--[[
  创建订单
  所需的参数
  带引号皆为字符串类型 其余小数或整数型
]]

--V免签URL地址
url = "http://1.15.17.207:99";
--创建订单接口
orderurl = url.."/createOrder";
--服务端状态接口
appurl = url.."/getState";
--查询订单接口
orderIdurl = url.."/getOrder";
--关闭订单
closeOrderurl = url.."/closeOrder";
--查询订单状态接口[客户端回调接口]
Callbackurl = url.."/checkOrder";
--通讯密钥
key = "181cf529de2a12ca200beffe6b1efef9";
--[必传参数]
--商户订单号，可以是时间戳，不可重复 字符串类型
payId = "nil";
--微信传入1 支付宝传入2
type = {1,2};
--订单金额
price = 0.01;
--签名 计算方式为 md5(payId+param+type+price+通讯密钥)
sign = "nil";
--[可选参数]
--传输参数，将会原样返回到异步和同步通知接口 字符串类型
param = nil；
--传入1则自动跳转到支付页面，否则返回创建结果的json数据
isHtml = nil;
--传入则设置该订单的异步通知接口为该参数，不传或传空则使用后台设置的接口
notifyUrl = "nil";
--传入则设置该订单的同步通知接口为该参数，不传或传空则使用后台设置的接口
returnUrl = "nil";
--当前系统时间戳
time = os.time();
--网络
wl=activity.getApplicationContext().getSystemService(Context.CONNECTIVITY_SERVICE).getActiveNetworkInfo();
payId = math.random(100000000000000,999999999999999);
--[[
   创建订单 发起支付
   @param paytype为支付类型 1为微信 2为支付宝
   @param returntype为回调类型 1为自动跳转支付页面 否则返回JSON
]]
function Pay(paytype,returntype)
  --方法内赋值 防止多订单重复订单号
  payId = math.random(100000000000000,999999999999999);
  --拼接参数值
  local data = payId..type[paytype]..price..key;
  --取参数MD5
  local sign = MD5(data);
  --拼接请求参数
  local parameter = "?payId="..payId.."&type="..type[paytype].."&price="..price.."&isHtml="..returntype.."&sign="..sign;
  if (wl == nil) then
    print("网络无连接！请检查网络连接");
   else
    --code状态 content内容
    Http.get(orderurl..parameter,cookie,charset,header,function(code,content,cookie,header)
      if (code ~= 200) then
        print("创建订单失败~");
       else
        data = cjson.decode(content);
        msg = content:match('"msg":"(.-)",');
        --二维码内容
        payUrl = content:match('"payUrl":"(.-)",');
        payUrl1=data["data"]["payUrl"];
        --云端订单号
        orderId = data["data"]["orderId"];
        --支付类型
        payType = data["data"]["payType"];
        --订单状态
        date = data["data"]["date"];
        --订单有效时间 分钟 取int类型
        timeOut = tointeger(data["data"]["timeOut"]);
        --分转秒
        timeOut1 = timeOut*60;
        --订单创建时间
        date = data["data"]["date"];
        --实际支付金额
        reallyPrice = data["data"]["reallyPrice"];

        if (paytype == 1) then
          --微信支付
          local wx=AlertDialog.Builder(this)
          .setTitle("微信支付")
          .setCancelable(false)
          .setView(loadlayout(wxpay_layout))
          .setPositiveButton("关闭订单",{onClick=function();
              --closeOrder(orderId);
          end})
          wx.show();
          --调用函数 Bitmap转码 显示二维码
          wx_qrcode(payUrl1);
          --将支付金额显示到页面
          reallyPrice1.Text = "￥"..reallyPrice;

          --订单信息显示
          payId2.text = tostring(payId);
          orderId2.text = tostring(orderId);
          reallyPrice2.text = reallyPrice;
          --创建时间
          date2.text = os.date("%Y-%m-%d %H:%M:%S",date);

          --收款码
          wxqrcode.onClick=function()
            activity.finish()
            intent=Intent();
            intent.setComponent(ComponentName("com.tencent.mm", "com.tencent.mm.ui.LauncherUI"));
            intent.putExtra("LauncherUI.From.Scaner.Shortcut", true);
            intent.setFlags(335544320);
            intent.setAction("android.intent.action.VIEW");
            activity.startActivity(intent);
          end
          --打印剩余有效支付时间
          for s=timeOut1,0,-1 do
            if (s~=0) then
              --定时器 用于倒计时自减操作
              wxds=Ticker();
              wxds.Period=1000;
              wxds.onTick=function();
                --参数值自减1 --循环--延时
                s = s-1;
                if (s ~= 0) then
                  times.text = s.."秒";
                 elseif (date == "-1") then
                  print("订单已过期");
                  ddtext.text="订单已过期：";
                  --设置过期二维码
                  wxqrcode.setImageBitmap(loadbitmap("assets/pay_no.png"));
                  --停止定时器
                  wxds.stop();
                 elseif (date == "0") then
                  print("等待支付...");
                 elseif (date == "1") then
                  print("支付完成~");
                 elseif (date == "2") then
                  print("支付完成但通知失败！");
                end
              end
            end
            break
          end
          --启动定时器
          wxds.start();
          print("请求状态："..code.."\nmsg："..msg);
         else
          --支付宝支付--##############
          local ali=AlertDialog.Builder(this)
          .setTitle("支付宝支付")
          .setCancelable(false)
          .setView(loadlayout(alipay_layout))
          .setPositiveButton("关闭订单",{onClick=function();

          end})
          ali.show();
          alipayweb.loadUrl(payUrl);
          print("请求状态："..code.."\nmsg："..msg);
        end
        --订单回调定时器
        ht=Ticker();
        ht.Period=3000;
        ht.onTick=function();
          Http.get(Callbackurl.."?orderId="..orderId,function(code,content)
            if(code ~= 200)then
              print("请求失败~");
             else
              --支付状态
              code1 = content:match('"code":(.-),');
              msg = content:match('"msg":"(.-)",');
              data = content:match('"data":"(.-)"}');
              if (code1 == "1" or msg == "成功") then
                print("订单已支付,即将跳转..");
                if (payType == "1") then
                  wxqrcode.setImageBitmap(loadbitmap("assets/pay_ok.png"));
                  activity.newActivity("pay_ok");
                  ht.stop();
                 else
                  activity.newActivity("pay_ok");
                  ht.stop();
                end
               else
                print("订单未支付,正在检测状态..");
              end
              --设置最长监听时间 超时结束回调检测
              task(15000,function()
                if (code1 == "-1") then
                  ht.stop();
                end
              end)
            end
          end)
        end
        ht.start();
      end
    end)
  end
end
--订单查询
cxorderId.onClick=function()
  if (wl == nil) then
    print("网络无连接！请检查网络连接");
   else
    --订单长度
    cd = (#editorderId.text);
    if (editorderId.text == "") then
      print("云端订单号不能为空");
     elseif (cd < 18) then
      print("云端订单号错误");
     else
      Http.get(orderIdurl.."?orderId="..editorderId.Text,function(code,content)
        msg = content:match('"msg":"(.-)",');
        data = cjson.decode(content);
        --商户订单号
        payId3 = data["data"]["payId"];
        --云端号
        orderId3 = data["data"]["orderId"];
        --支付type
        payType3 = tointeger(data["data"]["payType"]);
        --订单金额
        price3 = data["data"]["price"];
        --实际支付
        reallyPrice3 = data["data"]["reallyPrice"];
        --二维码内容
        payUrl3 = data["data"]["payUrl"];
        --支付状态
        state3 =tointeger(data["data"]["state"]);
        --创建时间戳
        date3 = data["data"]["date"];
        --时间戳转日期
        datetime = os.date("%Y-%m-%d %H:%M:%S",date3);
        data1 = "状态码："..code.."\n查询状态："..msg.."\n商户订单号："..payId3.."\n云端订单号："..orderId3.."\n支付方式："..payType3.."\n订单金额："..price3.."\n实际支付金额："..reallyPrice3.."\n二维码内容："..payUrl3.."\n支付状态："..state3.."\n创建时间："..datetime;

        AlertDialog.Builder(this)
        .setTitle("订单信息：")
        .setCancelable(false)
        .setMessage(data1)
        .setPositiveButton("我知道了",nil)
        .setNeutralButton("复制信息",{onClick=function(v) activity.getSystemService(Context.CLIPBOARD_SERVICE).setText(data1)print("复制成功~")end})
        .show();
      end)
    end
  end
end

--转码
function wx_qrcode(wx_url)
  --图标地址
  Bit = BitmapFactory.decodeFile("assets/wxpay.png");
  --t为二维码地址
  local url = wx_url;
  if url ~= "" then
    --带图标参数为 二维码地址，大小，图标地址，颜色
    qr_code = QrCode.iconQrcode(url,500,Bit,0xff00a2ff);
    --转二维码至imageview
    wxqrcode.setImageBitmap(qr_code);
   else
    print("请传入二维码地址");
  end
end

--监控状态
function App()
  if (wl == nil)then
    print("网络无连接！请检查网络连接");
    appicon.setImageBitmap(loadbitmap("assets/state.png"));
   else
    local sign = MD5(time..key);
    Http.get(appurl.."?t="..time.."&sign="..sign,function(code,appstate)
      if (code ~= 200) then
        print("服务器连接失败~");
        appicon.setImageBitmap(loadbitmap("assets/no.png"));
       else
        data = cjson.decode(appstate);
        code = appstate:match('"code":(.-),');
        msg = appstate:match('"msg":"(.-)",');
        --最后一次监控端向服务器发送心跳的时间戳（10位）
        lastheart = tostring(data["data"]["lastheart"]);
        --当前时间戳减最后监听时间戳 取整数判断
        state = tointeger(time - lastheart);

        if (code == "1" and state < 30 ) then
          print("监控已在线");
          --动态设置图片
          appicon.setImageBitmap(loadbitmap("assets/yes.png"));
         elseif (state > 30) then
          print("监控已掉线");
          appicon.setImageBitmap(loadbitmap("assets/no.png"));
         else
          print("监控未绑定");
          appicon.setImageBitmap(loadbitmap("assets/state.png"));
        end
      end
    end)
  end
end
App();

pay1.onClick = function()
  local syt=AlertDialog.Builder(this)
  .setTitle("支付收银台")
  .setCancelable(false)
  .setView(loadlayout(pay))
  .setPositiveButton("关闭窗口",{onClick=function()

  end})
  syt.show();

  function Alipay.onClick()
    print("已选择支付宝付款！");
    if alikg.isSelected() then
      alikg.Checked=false;
     else
      alikg.Checked=true;
    end
  end


  function WeChat.onClick()
    print("已选择微信付款！")
    if wxkg.isSelected() then
      wxkg.Checked=false;
     else
      wxkg.Checked=true;
    end
  end


  alikg.setOnCheckedChangeListener{
    onCheckedChanged=function(g,c);
      if c then
        wxkg.Checked=false;
      end
  end}


  wxkg.setOnCheckedChangeListener{
    onCheckedChanged=function(g,c);
      if c then
        alikg.Checked=false;
      end
  end}
  --默认选择
  wxkg.Checked=true;
  --请求支付
  payButton.onClick=function()
    if (alikg.Checked)then
      Pay(2,0);
     else
      Pay(1,0);
    end
  end
end

alipay_layout = {

  LinearLayout;
  gravity="center";
  orientation="vertical";
  {
    LuaWebView;
    layout_width="match_parent";
    id="alipayweb";
    layout_height="match_parent";
  };
};

wxpay_layout = {

  LinearLayout;
  layout_height="match_parent";
  layout_width="match_parent";
  orientation="vertical";
  {
    LinearLayout;
    layout_height="100dp";
    layout_width="match_parent";
    orientation="horizontal";
    gravity="center";
    {
      ImageView;
      id="wx_icon";
      layout_width="110dp";
      background="assets/wechat.png";
      layout_height="45dp";
    };
  };
  {
    LinearLayout;
    layout_height="400dp";
    layout_width="match_parent";
    orientation="vertical";
    gravity="center";
    {
      TextView;
      layout_marginBottom="20dp";
      TextSize="10dp";
      layout_width="match_parent";
      text="¥";
      gravity="center";
      textColor="0xFFFF0000";
      layout_gravity="center";
      id="reallyPrice1";
      textSize="30sp";
    };
    {
      ImageButton;
      id="wxqrcode";
      layout_width="wrap";
      layout_gravity="center";
      layout_height="wrap_content";
    };
    {
      LinearLayout;
      layout_marginTop="20dp";
      layout_marginBottom="30dp";
      gravity="center";
      layout_height="30dp";
      layout_width="match_parent";
      orientation="horizontal";
      {
        TextView;
        id="ddtext";
        textSize="20sp";
        text="订单剩余时间：";
      };
      {
        TextView;
        id="times";
        text="00秒";
        layout_marginRight="10dp";
        textSize="20sp";
      };
    };
    {
      TextView;
      textColor="0xFF00B1FF";
      text="截图保存二维码点击图片打开微信扫一扫";
    };
    {
      TextView;
      textColor="0xFF00B1FF";
      text="扫码后输入金额支付";
    };
  };
  {
    LinearLayout;
    layout_height="200dp";
    orientation="vertical";
    layout_width="match_parent";
    {
      LinearLayout;
      layout_height="30dp";
      orientation="horizontal";
      layout_width="match_parent";
      {
        TextView;
        layout_height="30dp";
        text="商户订单号：";
        gravity="center";
        textSize="15sp";
      };
      {
        TextView;
        textIsSelectable=true;--可选择复制
        gravity="center";
        text="";
        layout_marginLeft="180dp";
        textSize="15sp";
        layout_height="30dp";
        textColor="0xFF00FF00";
        id="payId2";
      };
    };
    {
      LinearLayout;
      layout_height="30dp";
      orientation="horizontal";
      layout_width="match_parent";
      {
        TextView;
        text="云端订单号：";
        layout_height="30dp";
        gravity="center";
        textSize="15sp";
      };
      {
        TextView;
        textIsSelectable=true;
        text="";
        gravity="center";
        id="orderId2";
        layout_marginLeft="158dp";
        textSize="15sp";
        layout_height="30dp";
        textColor="0xFF00FF00";
      };
    };
    {
      LinearLayout;
      layout_height="30dp";
      orientation="horizontal";
      layout_width="match_parent";
      {
        TextView;
        layout_height="30dp";
        text="订单金额：";
        textSize="15sp";
        gravity="center";
      };
      {
        TextView;
        text="";
        id="reallyPrice2";
        gravity="center";
        layout_marginLeft="273dp";
        textSize="15sp";
        layout_height="30dp";
        textColor="0xFF00FF00";
      };
    };
    {
      LinearLayout;
      layout_height="30dp";
      orientation="horizontal";
      layout_width="match_parent";
      {
        TextView;
        text="订单创建时间：";
        gravity="center";
        textSize="15sp";
        layout_height="30dp";
      };
      {
        TextView;
        text="";
        id="date2";
        gravity="center";
        layout_marginLeft="150dp";
        textSize="15sp";
        layout_height="30dp";
        textColor="0xFF00FF00";
      };
    };
    {
      LinearLayout;
      layout_height="30dp";
      layout_width="match_parent";
      orientation="horizontal";
      {
        TextView;
        text="支付状态：";
        layout_height="30dp";
        textSize="15sp";
        gravity="center";
      };
      {
        TextView;
        text="未支付";
        textSize="15sp";
        layout_marginLeft="260dp";
        gravity="center";
        layout_height="30dp";
        textColor="0xFF00FF00";
      };
    };
  };
};

pay = {
  LinearLayout;
  gravity="center";
  layout_height="fill";
  layout_width="fill";
  {
    LinearLayout;
    orientation="vertical";
    gravity="left";
    layout_width="match_parent";
    layout_height="match_parent";
    {
      CardView;
      layout_margin="10dp";
      layout_height="wrap_content";
      layout_width="match_parent";
      {
        LinearLayout;
        orientation="vertical";
        layout_width="match_parent";
        {
          TextView;
          text="支付金额";
          gravity="center";
          layout_marginTop="20dp";
          textSize="15sp";
          layout_width="match_parent";
        };
        {
          TextView;
          text="¥0.01";
          gravity="center";
          textColor="#000000";
          textSize="20sp";
          layout_width="match_parent";
        };
        {
          LinearLayout;
          layout_marginLeft="10dp";
          orientation="horizontal";
          layout_marginTop="10dp";
          layout_width="match_parent";
          layout_marginRight="10dp";
          {
            TextView;
            text="商品名";
            textSize="15sp";
            textColor="#ff393939";
          };
          {
            TextView;
            text="V免签支付测试";
            gravity="right";
            textColor="#ff393939";
            textSize="15sp";
            layout_width="match_parent";
          };
        };
        {
          LinearLayout;
          layout_marginRight="10dp";
          layout_marginTop="10dp";
          layout_width="match_parent";
          layout_marginLeft="10dp";
          {
            TextView;
            text="订单号";
            textSize="15sp";
            textColor="#ff393939";
          };
          {
            TextView;
            text="686309888046";
            gravity="right";
            textColor="#ff393939";
            textSize="15sp";
            layout_width="match_parent";
          };
        };
        {
          TextView;
          background="#ff393939";
          layout_height="1";
          layout_marginLeft="15dp";
          layout_marginRight="15dp";
          layout_marginTop="20dp";
          layout_width="match_parent";
          layout_marginBottom="15dp";
        };
        {
          LinearLayout;
          orientation="vertical";
          layout_width="match_parent";
          {
            LinearLayout;
            paddingLeft="5dp";
            layout_height="55dp";
            paddingRight="5dp";
            orientation="horizontal";
            id="Alipay";
            layout_width="match_parent";
            gravity="center_vertical";
            {
              ImageView;
              layout_height="35dp";
              src="assets/appicon.png";
              layout_width="35dp";
            };
            {
              LinearLayout;
              paddingLeft="10dp";
              layout_height="match_parent";
              orientation="vertical";
              gravity="center_vertical";
              layout_width="match_parent";
              layout_weight="1";
              {
                TextView;
                text="支付宝支付";
                textColor="#ff2d2d2d";
              };
              {
                TextView;
                text="推荐使用支付宝支付";
                layout_marginTop="5dp";
                textSize="13sp";
              };
            };
            {
              CheckBox;
              id="alikg";
            };
          };
          {
            LinearLayout;
            paddingLeft="5dp";
            layout_height="55dp";
            paddingRight="5dp";
            orientation="horizontal";
            id="WeChat";
            layout_width="match_parent";
            gravity="center_vertical";
            {
              ImageView;
              layout_height="35dp";
              src="assets/gfff.png";
              layout_width="35dp";
            };
            {
              LinearLayout;
              paddingLeft="10dp";
              layout_height="match_parent";
              orientation="vertical";
              gravity="center_vertical";
              layout_width="match_parent";
              layout_weight="1";
              {
                TextView;
                text="微信支付";
                textColor="#ff2d2d2d";
              };
              {
                TextView;
                text="WeChat Pay";
                layout_marginTop="5dp";
                textSize="13sp";
              };
            };
            {
              CheckBox;
              id="wxkg";
            };
          };
        };
      };
    };
    {
      Button;
      text="支付";
      layout_width="match_parent";
      textColor="#ffffff";
      layout_marginRight="10dp";
      id="payButton";
      backgroundColor="#ff00b8ff";
      layout_marginLeft="10dp";
    };
  };
};