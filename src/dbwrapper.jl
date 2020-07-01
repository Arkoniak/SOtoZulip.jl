function create_so_tables(db)
    create_qq = """
    CREATE TABLE IF NOT EXISTS questions
    (
        qid INTEGER PRIMARY KEY,
        zuid INTEGER,
        title TEXT,
        score INTEGER,
        answers INTEGER,
        bodyhash TEXT,
        isanswered INT,
        qcreated INT,
        qactivity INT,
        created TEXT,
        updated TEXT
    ) WITHOUT ROWID
    """
    DBInterface.execute(db, create_qq)
    SQLite.createindex!(db, "questions", "qid_index", "qid"; unique=true, ifnotexists=true)

    create_ansq = """
    CREATE TABLE IF NOT EXISTS answers
    (
        qid INTEGER NOT NULL,
        zuid INTEGER,
        answerid INTEGER PRIMARY KEY,
        isaccepted INT,
        bodyhash TEXT,
        score INT,
        acreated INT,
        aactivity INT,
        created TEXT,
        updated TEXT
    ) WITHOUT ROWID
    """
    DBInterface.execute(db, create_ansq)
    SQLite.createindex!(db, "answers", "aqid_index", "qid"; unique=false, ifnotexists=true)
    SQLite.createindex!(db, "answers", "aid_index", "answerid"; unique=true, ifnotexists=true)
end

md5hash(text) = bytes2hex(md5(text))

function qissame(q, row)
    return (row.score == q.score) & (row.bodyhash == md5hash(q.body)) & (row.answers == q.answer_count) & (row.isanswered == Int(q.is_answered))
end

function qstatus(db, q)
    query = """
    SELECT qid, zuid, score, answers, isanswered, bodyhash, title
    FROM questions
    WHERE qid = ?
    """

    stmt = SQLite.Stmt(db, query)
    res = DBInterface.execute(stmt, (q.question_id, ))
    status = "new"
    title = ""
    msg_id = 0
    for row in res
        msg_id = row.zuid
        title = row.title
        status = qissame(q, row) ? "known" : "update"
    end
    
    return (status = status, msg_id = msg_id, title = title)
end

function issame(x::Answer, row)
    return (row.bodyhash == md5hash(x.body)) & (row.isaccepted == Int(x.is_accepted)) & (row.score == x.score)
end

function astatus(db, a::Answer)
    query = """
    SELECT a.qid, a.title, b.answerid, b.zuid, b.isaccepted, b.bodyhash, b.score
    FROM questions AS a
    LEFT OUTER JOIN (
        SELECT qid, answerid, zuid, isaccepted, bodyhash, score
        FROM answers
        WHERE qid = ?1 AND answerid = ?2
    ) AS b
        ON a.qid = b.qid
    WHERE a.qid = ?1
    """

    stmt = SQLite.Stmt(db, query)
    res = DBInterface.execute(stmt, (a.question_id, a.answer_id))
    status = "new"
    title = ""
    msg_id = 0
    for row in res
        title = row.title
        ismissing(row.answerid) && break
        msg_id = row.zuid
        status = issame(a, row) ? "known" : "update"
    end
    
    return (status = status, msg_id = msg_id, title = title)
end

currentts() = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")

function addquestion!(db, q, response)
    query = """
    INSERT INTO questions(qid, zuid, title, score, answers, bodyhash, isanswered, qcreated, qactivity, created, updated) VALUES  (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
    """

    stmt = SQLite.Stmt(db, query)
    ts = currentts()
    DBInterface.execute(stmt, (q.question_id, response.id, q.title, q.score, q.answer_count, bytes2hex(md5(q.body)), q.is_answered, q.creation_date, q.last_activity_date, ts, ts))
end

function updquestion!(db, q)
    query = """
    UPDATE questions
    SET score = ?2,
        answers = ?3,
        bodyhash = ?4,
        isanswered = ?5,
        qactivity = ?6,
        updated = ?7
    WHERE
        qid = ?1
    """

    stmt = SQLite.Stmt(db, query)
    ts = currentts()
    DBInterface.execute(stmt, (q.question_id, q.score, q.answer_count, bytes2hex(md5(q.body)), q.is_answered, q.last_activity_date, ts))
end

function add!(db, a::Answer, response)
    query = """
    INSERT INTO answers(qid, zuid, answerid, isaccepted, bodyhash, score, acreated, aactivity, created, updated) VALUES  (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
    """

    stmt = SQLite.Stmt(db, query)
    ts = currentts()
    DBInterface.execute(stmt, (a.question_id, response.id, a.answer_id, a.is_accepted, md5hash(a.body), a.score, a.creation_date, a.last_activity_date, ts, ts))
end

function update!(db, a::Answer)
    query = """
    UPDATE answers
    SET isaccepted = ?3,
        bodyhash = ?4,
        score = ?5,
        aactivity = ?6,
        updated = ?7
    WHERE
        qid = ?1 AND answerid = ?2
    """

    stmt = SQLite.Stmt(db, query)
    ts = currentts()
    DBInterface.execute(stmt, (a.question_id, a.answer_id, a.is_accepted, md5hash(a.body), a.score, a.last_activity_date, ts))
end

invalidate_question(db, x::AbstractVector) = @_ foreach(invalidate_question(db, _), x)
function invalidate_question(db, x)
    query = """
    UPDATE questions
    SET bodyhash = ""
    WHERE qid = ?
    """

    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (x, ))
end

invalidate_answer(db, x::AbstractVector) = @_ foreach(invalidate_answer(db, _), x)
function invalidate_answer(db, x)
    query = """
    UPDATE answers
    SET bodyhash = ""
    WHERE answerid = ?
    """

    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (x, ))
end
