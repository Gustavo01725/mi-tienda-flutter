<?php require getcwd()."/vendor/autoload.php"; $app=require getcwd()."/bootstrap/app.php"; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$o=App\Models\Order::latest('id')->first(); echo "order {$o->code} unpaid? ", $o->payment_status, " details=", $o->orderDetails()->count(), " total=", $o->grand_total, "\n";
$o->markPaid('stripe','pi_test'); App\Models\Cart::where('user_id',$o->user_id)->delete();
echo "stock after pay: ", App\Models\ProductStock::pluck('qty','variant')->toJson(), "\n";
