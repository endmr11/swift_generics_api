import UIKit



class ViewController: UIViewController {

    let usersUrl = URL(string: "https://jsonplaceholder.typicode.com/users")
    let todolistUrl = URL(string: "https://jsonplaceholder.typicode.com/todos")
    let kisilerUrl = URL(string: "")
    private var models:[Codable] = []
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        //fetchUsersData()
        //fetchTodosData()
        Task.init{
            await addTodosDataAsync()
        }
        Task.init {
            await fetchTodosDataAsync()
        }

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    func fetchUsersData(){
        URLSession.shared.customRequest(
            url: usersUrl,
            model: [UserModel].self) {[weak self] result in
                switch result{
                case .success(let users):
                    print(users)
                    DispatchQueue.main.async {
                        self?.models = users
                        self?.tableView.reloadData()
                    }
                case .failure(let error):
                    print(error)
                }
            }
    }
    
    func fetchTodosData(){
        URLSession.shared.customRequest(
            url: todolistUrl,
            model: [TodoModel].self) {[weak self] result in
                switch result{
                case .success(let todos):
                    print(todos)
                    DispatchQueue.main.async {
                        self?.models = todos
                        self?.tableView.reloadData()
                    }
                case .failure(let error):
                    print(error)
                }
            }
    }
    
    func fetchTodosDataAsync() async {
        let result = try? await URLSession.shared.customRequestAsync(
            url: todolistUrl,
            model: [TodoModel].self,
            requestType: RequestType.GET,
            queryParameters: nil,
            body: nil,
            onFail: {
                print("onFail")
            })
        switch result{
        case .success(let todos):
            print(todos)
            DispatchQueue.main.async {
                self.models = todos
                self.tableView.reloadData()
            }
        case .failure(let error):
            print(error)
        case .none:
            print("none")
        }
    }
    
    func addTodosDataAsync() async {
        let result = try? await URLSession.shared.customRequestAsync(
            url: kisilerUrl,
            model: Kisi.self,
            requestType: RequestType.POST,
            queryParameters: nil,
            body: ["kisi_ad":"TestAlo","kisi_tel":"5454"],
            onFail: {
                print("onFail")
            })
        switch result{
        case .success(let todos):
            print(">>>>>> success: \(todos)")
        case .failure(let error):
            print(">>>>>> error: \(error)")
        case .none:
            print("none")
        }
    }


}
extension ViewController: UITableViewDelegate,UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let user = models[indexPath.row] as? UserModel
        let todo = models[indexPath.row] as? TodoModel
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = user?.name
        cell.textLabel?.text = todo?.title
        if let item = todo?.completed {
            cell.accessoryType = item ? .checkmark : .none
        }
        return cell
    }
}

extension URLSession{
    enum NetworkError: Error{
        case urlError
        case dataError
    }
    func customRequest<T: Codable>(
        url: URL?,
        model: T.Type,
        completion: @escaping(Result<T,Error>)->Void
    ){
        guard let url = url else {
            completion(.failure(NetworkError.urlError))
            return
        }
        let task = self.dataTask(with: url) { data, _, error in
            guard let data = data else {
                if let error = error {
                    completion(.failure(error))
                }else{
                    completion(.failure(NetworkError.dataError))
                }
                return
            }
            do {
                let result = try JSONDecoder().decode(model, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    func customRequestAsync<T: Codable>(
        url: URL?,
        model:T.Type,
        requestType: RequestType,
        queryParameters: [String: String]?,
        body: [String: Any]?,
        onFail: @escaping () -> ()
    )async throws -> Result<T,Error> {
        let res = try? await handleRequest(url: url,model: model, requestType: requestType, queryParameters: queryParameters, body: body, onFail: onFail)
        if let res = res {
            return res
        }
        return .failure(NetworkError.dataError)
    }
    
    func handleRequest<T: Codable>(
        url: URL?,
        model:T.Type,
        requestType: RequestType,
        queryParameters: [String: String]?,
        body: [String: Any]?,
        onFail: @escaping () -> ()
    ) async throws -> Result<T,Error> {
        if requestType == .GET {
            guard let url = url else {
                return (.failure(NetworkError.urlError))
            }
            let (data,_) = try await URLSession.shared.data(from: url)

            if let datas = try? JSONDecoder().decode(model, from: data){
                return .success(datas)
            }
            return .failure(NetworkError.dataError)
        }else if requestType == .POST {
                guard let url = url else {
                    return (.failure(NetworkError.urlError))
                }
                var request = URLRequest(url: url)
            request.httpMethod = requestType.rawValue
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                let payload = try? JSONSerialization.data(withJSONObject: body!, options: [])
                let (data, _) = try await URLSession.shared.upload(for: request, from: payload!)
                if let datas = try? JSONDecoder().decode(model, from: data){
                    return .success(datas)
                }
                return .failure(NetworkError.urlError)
        }else{
            return .failure(NetworkError.urlError)
        }
        
    }
}
struct UserModel:Codable {
    let name: String
    let email: String
}

struct TodoModel:Codable {
    let title: String
    let completed: Bool
}


class Kisi:Codable {
    var kisi_id:String?
    var kisi_ad:String?
    var kisi_tel:String?
    
    
    init(kisi_id:String,kisi_ad:String,kisi_tel:String)  {
        self.kisi_id = kisi_id
        self.kisi_ad = kisi_ad
        self.kisi_tel = kisi_tel
    }
}

enum RequestType: String, CaseIterable {
   case GET
   case PUT
   case DELETE
   case POST
}
