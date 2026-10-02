B=http://localhost:8000/api; H='-H Accept:application/json -H Content-Type:application/json'
j(){ python3 -c "import sys,json; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }
login(){ curl -s -m 20 $H -X POST $B/auth/login -d "{\"email\":\"$1\",\"password\":\"secret123\"}" | j "d['token']"; }
c(){ t=$1; shift; curl -s -m 20 $H -H "Authorization: Bearer $t" "$@"; }
CT=$(login cust@t.com); ST=$(login seller@t.com); AT=$(login admin@t.com); echo "tokens ${#CT} ${#ST} ${#AT}"
c $CT -X POST $B/cart -d '{"product_id":1,"variation":"M-negro","quantity":2}' | j "('cart total',d['total'])"
c $CT -X POST $B/checkout/intent -d '{"full_name":"Cli E","phone":"099","email":"cust@t.com","address":"Calle 1","city":"Quito"}' -o /dev/null -w 'intent (sin Stripe) [%{http_code}]\n'
php "$(dirname "$0")/pay.php" 2>&1 | head -4
echo "--customer orders"; c $CT $B/orders | j "[(o['code'][:12],o['payment_status'],o['delivery_status'],o['grand_total']) for o in d]"
echo "--cart emptied after payment"; c $CT $B/cart | j "d['count']"
echo "--seller orders"; c $ST $B/seller/orders | j "[(o['id'],o['payment_status'],o['delivery_status'],[i['name'] for i in o['items']]) for o in d]"
echo "--seller notif (new sale)"; c $ST $B/notifications | j "(d['unread_count'],[n['message'] for n in d['data']])"
echo "--seller confirm"; c $ST -X POST $B/seller/orders/1/confirm | j "d['delivery_status']"
echo "--confirm again (expect 422)"; c $ST -X POST $B/seller/orders/1/confirm -o /dev/null -w '[%{http_code}]\n'
echo "--customer cannot confirm (expect 403)"; c $CT -X POST $B/seller/orders/1/confirm -o /dev/null -w '[%{http_code}]\n'
echo "--seller send to warehouse"; c $ST -X POST $B/seller/orders/1/send-to-warehouse | j "d['delivery_status']"
echo "--customer sync orders"; c $CT $B/sync/orders | j "[(o['id'],o['delivery_status']) for o in d['changed']]"
echo "--customer notifications"; c $CT $B/notifications | j "(d['unread_count'],[n['message'][:60] for n in d['data']])"
echo "--admin notifications"; c $AT $B/notifications | j "(d['unread_count'],[n['message'][:55] for n in d['data']])"
echo "--mark all read"; c $CT -X POST $B/notifications/read-all >/dev/null; c $CT $B/notifications | j "d['unread_count']"
echo "--other user's order (expect 404)"; c $AT $B/orders/999 -o /dev/null -w '[%{http_code}]\n'
echo "--logout then me (expect 401)"; c $CT -X POST $B/auth/logout >/dev/null; c $CT $B/auth/me -o /dev/null -w '[%{http_code}]\n'
